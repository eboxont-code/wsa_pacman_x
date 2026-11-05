// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures, non_constant_identifier_names



import 'dart:ui';

import 'package:flutter/material.dart' as material;
import 'package:mdi/mdi.dart';
import 'package:flutter_localizations/flutter_localizations.dart' as locale;
import 'package:wsa_pacman/android/android_utils.dart';
import 'package:wsa_pacman/apk_installer.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
//import 'package:flutter/material.dart' hide showDialog;
import 'package:shared_value/shared_value.dart';
import 'package:wsa_pacman/io/isolate_runner.dart';
import 'package:wsa_pacman/utils/misc_utils.dart';
import 'package:wsa_pacman/utils/adb_connection.dart';
import 'package:wsa_pacman/utils/wsa_utils.dart';
import 'package:wsa_pacman/utils/locale_utils.dart';
import 'package:wsa_pacman/widget/themed_pane_item.dart';
import 'package:wsa_pacman/windows/win_info.dart';
import 'package:wsa_pacman/windows/win_reg.dart';
import 'package:wsa_pacman/windows/wsa_status.dart';
import 'global_state.dart';

import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:url_strategy/url_strategy.dart';

import 'screens/wsa.dart';
import 'screens/settings.dart';
import 'utils/string_utils.dart';

import 'dart:io';
import 'dart:developer';
import 'dart:async';

import 'theme.dart';

const String appTitle = 'WSA Package Manager';
const String appVersion = '1.5.0';


class WSAStatusAlert {
  WSAStatusAlert(this.type, this.severity, this.title, this.desc);

  final ConnectionStatus type;
  final InfoBarSeverity severity;
  final String Function(AppLocalizations lang) title;
  final String Function(AppLocalizations lang) desc;

  bool get isConnected => type == ConnectionStatus.CONNECTED;
  bool get isDisconnected => type != ConnectionStatus.CONNECTED;
  bool get isPoweredOn => isConnected || type == ConnectionStatus.DISCONNECTED 
    || type == ConnectionStatus.OFFLINE || type == ConnectionStatus.UNAUTHORIZED;
}

enum ConnectionStatus {
  UNSUPPORTED, MISSING, UNKNOWN, ARRESTED, STARTING, OFFLINE, DISCONNECTED, CONNECTED, UNAUTHORIZED
}
extension on ConnectionStatus {
  static final Map<ConnectionStatus, WSAStatusAlert> _statusAlers = {
    ConnectionStatus.UNSUPPORTED: WSAStatusAlert(ConnectionStatus.UNSUPPORTED, InfoBarSeverity.error, (l)=>l.status_unsupported, 
      (l)=>l.status_unsupported_desc(WinVer.isWindows10OrGreater ? l.status_subtext_winver_10 : l.status_subtext_winver_older)),
    ConnectionStatus.MISSING: WSAStatusAlert(ConnectionStatus.MISSING, InfoBarSeverity.error, (l)=>l.status_missing, (l)=>l.status_missing_desc),
    ConnectionStatus.UNKNOWN: WSAStatusAlert(ConnectionStatus.UNKNOWN, InfoBarSeverity.info, (l)=>l.status_unknown, (l)=>l.status_unknown_desc),
    ConnectionStatus.STARTING: WSAStatusAlert(ConnectionStatus.STARTING, InfoBarSeverity.info, (l)=>l.status_starting, (l)=>l.status_starting_desc),
    ConnectionStatus.ARRESTED: WSAStatusAlert(ConnectionStatus.ARRESTED, InfoBarSeverity.warning, (l)=>l.status_arrested, (l)=>l.status_arrested_desc),
    ConnectionStatus.OFFLINE: WSAStatusAlert(ConnectionStatus.OFFLINE, InfoBarSeverity.warning, (l)=>l.status_offline, (l)=>l.status_offline_desc),
    ConnectionStatus.DISCONNECTED: WSAStatusAlert(ConnectionStatus.DISCONNECTED, InfoBarSeverity.error, (l)=>l.status_disconnected, (l)=>l.status_disconnected_desc),
    ConnectionStatus.CONNECTED: WSAStatusAlert(ConnectionStatus.CONNECTED, InfoBarSeverity.success, (l)=>l.status_connected, (l)=>l.status_connected_desc),
    ConnectionStatus.UNAUTHORIZED: WSAStatusAlert(ConnectionStatus.UNAUTHORIZED, InfoBarSeverity.warning, (l)=>l.status_unauthorized, (l)=>'${l.status_unauthorized_desc}\n'),
  };

  WSAStatusAlert get statusAlert => _statusAlers[this] ?? WSAStatusAlert(this, InfoBarSeverity.error, (l)=>"Unmapped status",
    (l)=>"Encountered WSA connection status $this, the status is missing an alert message");
}

extension __EnumExtension on Enum {
  String name() {
    return toString().split('.').last.toLowerCase();
  }
}

class Env {
  static final String SYSTEM_ROOT = Platform.environment["SystemRoot"] ?? "";
  static final String USER_PROFILE = Platform.environment["UserProfile"] ?? "";
  static final String EXEC_DIR = Platform.resolvedExecutable.replaceFirst(RegExp(r'[/\\][^/\\]*$'), r'\');
  static final String TOOLS_DIR = "${EXEC_DIR}embedded-tools\\";
  static late final String POWERSHELL = WinReg.getString(RegHKey.HKEY_LOCAL_MACHINE, r'SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell', 'Path')?.value ?? '$SYSTEM_ROOT\\System32\\WindowsPowerShell\v1.0\\powershell.exe';
  static late final String WSA_SYSTEM_PATH = RegExp(r'^(.*)[\\/]+[^\\/]*[\\/]+[^\\/]*$').firstMatch(
      WinReg.getString(RegHKey.HKEY_LOCAL_MACHINE, r'SYSTEM\CurrentControlSet\Services\WsaService', 'ImagePath')?.value.unquoted ??
      WinReg.getString(RegHKey.HKEY_CURRENT_USER, r'Software\Microsoft\Windows\CurrentVersion\App Paths\WsaClient.exe', null)?.value ?? ''
    )?.group(1) ?? '';
  static late final String WSA_EXECUTABLE = '$WSA_SYSTEM_PATH\\WsaClient\\WsaClient.exe';
  static late final bool WSA_INSTALLED = File('$WSA_SYSTEM_PATH\\AppxManifest.xml').existsSync();
  static late final WSA_INFO = WSAPkgInfo.fromSystemPath(WSA_SYSTEM_PATH);
}

class WSAPeriodicConnector {
  static const PERIODIC_CHECK_BOOT_DURATION = Duration(milliseconds: 500);
  static const PERIODIC_CHECK_SLEEPING_DURATION = Duration(milliseconds: 750);
  static const PERIODIC_CHECK_CONNECT_DURATION = Duration(seconds: 5);
  static int lastStart = 0;
  static bool get shouldWaitStart => DateTime.now().millisecondsSinceEpoch - lastStart < 15000;
  static final DynamicTimer timer = DynamicTimer((Timer t) => WSAPeriodicConnector._checkConnectionStatus());
  static ConnectionStatus status = ConnectionStatus.UNKNOWN;
  static WSAStatusAlert alertStatus = ConnectionStatus.UNKNOWN.statusAlert;
  static bool _statusInitialized = false;

  static bool _connectionCheckInProgress = false;

  static void _checkConnectionStatus() async {
    // Timer.periodic does not wait for async callbacks. Do not overlap slow
    // WSA/ADB probes when startup takes longer than a normal polling interval.
    if (_connectionCheckInProgress) return;
    _connectionCheckInProgress = true;
    try {
      await _checkConnectionStatusOnce();
    } catch (error, stackTrace) {
      log("WSA/ADB connection check failed: $error\n$stackTrace");
      final fallbackStatus = Env.WSA_INSTALLED
          ? ConnectionStatus.OFFLINE
          : ConnectionStatus.DISCONNECTED;
      if (status != fallbackStatus) {
        GState.connectionStatus.$ = (status = fallbackStatus).statusAlert;
      }
    } finally {
      _connectionCheckInProgress = false;
    }
  }

  static Future<void> _checkConnectionStatusOnce() async {
    if (_statusInitialized) {
      Process.run('${Env.SYSTEM_ROOT}\\System32\\tasklist.exe', []).then((result){
        if (!result.stdout.toString().contains(RegExp(r'(^|\n)adb.exe\s+'))) {
          status = ConnectionStatus.UNKNOWN;
          GState.connectionStatus.update((p0) => status.statusAlert);
        }
      });
    }

    if (!WSAStatus.isBooted) {
      timer.setDuration(PERIODIC_CHECK_BOOT_DURATION);
      ConnectionStatus newStatus = Env.WSA_INSTALLED ? ConnectionStatus.ARRESTED : WinVer.isWindows11OrGreater ? ConnectionStatus.MISSING : ConnectionStatus.UNSUPPORTED;
      if (status != newStatus) GState.connectionStatus.$ = (status = newStatus).statusAlert;
      return;
    }
    else if (!WSAStatus.isRunning) {
      timer.setDuration(PERIODIC_CHECK_SLEEPING_DURATION);
      ConnectionStatus newStatus = ConnectionStatus.ARRESTED;
      if (status != newStatus) GState.connectionStatus.$ = (status = newStatus).statusAlert;
      return;
    }
    else {
      timer.setDuration(PERIODIC_CHECK_CONNECT_DURATION);
      if (status == ConnectionStatus.ARRESTED || status == ConnectionStatus.MISSING || status == ConnectionStatus.UNSUPPORTED)
          lastStart = DateTime.now().millisecondsSinceEpoch;
    }

    final prevStatus = status;
    final process = await ADBUtils.devices(long: true);
    final output = process.stdout?.toString() ?? '';
    final configuredSerial = ADBUtils.deviceName;
    final wsaEndpoint = findWsaAdbEndpoint(
      output,
      preferredSerial: configuredSerial,
    );

    if (wsaEndpoint != null) {
      // Only adopt an alternate endpoint when ADB metadata identifies it as WSA.
      // A regular phone or emulator is never considered for endpoint adoption.
      if (GState.ipAddress.$ != wsaEndpoint.host) {
        GState.ipAddress
          ..update((_) => wsaEndpoint.host)
          ..persist();
      }
      if (GState.androidPort.$ != wsaEndpoint.port) {
        GState.androidPort
          ..update((_) => wsaEndpoint.port)
          ..persist();
        GState.androidPortPending.$ = wsaEndpoint.port.toString();
      }

      switch (wsaEndpoint.state) {
        case 'device':
          GState.adbConnectionDiagnostic.update((_) => "");
          status = ConnectionStatus.CONNECTED;
          break;
        case 'unauthorized':
          GState.adbConnectionDiagnostic.update((_) =>
              'ADB reports ${wsaEndpoint.serial} as unauthorized. The Android authorization prompt may need approval.');
          status = ConnectionStatus.UNAUTHORIZED;
          if (prevStatus == ConnectionStatus.UNKNOWN) reconnect();
          break;
        case 'offline':
          GState.adbConnectionDiagnostic.update((_) =>
              'ADB reports ${wsaEndpoint.serial} as offline.');
          status = (status == ConnectionStatus.ARRESTED ||
                  status == ConnectionStatus.STARTING) && shouldWaitStart
              ? ConnectionStatus.STARTING
              : ConnectionStatus.OFFLINE;
          break;
        case 'host':
          reconnect();
          break;
      }
    } else {
      await _tryConnect();
    }
    // No WSA endpoint was found in the device list, so _tryConnect()
    // was already attempted in the fallback branch above.
    if (status != prevStatus) GState.connectionStatus.update((p0) => status.statusAlert);
    _statusInitialized = false;
    log("Connection status: ${status.name()}");
  }

  static Future<void> reconnect() async {
    final previousStatus = status;
    await ADBUtils.disconnectWSA();
    await _tryConnect();
    if (status != previousStatus) {
      GState.connectionStatus.$ = status.statusAlert;
    }
  }

  static Future<void> _tryConnect() async {
    // On Windows, starting adb.exe/server can exceed 200 ms, especially just
    // after WSA boots. Keep this below the five-second polling interval.
    final ProcessResult process = await ADBUtils.connectWSA()
        .processTimeout(const Duration(seconds: 3));
    final stdout = process.stdout?.toString() ?? '';
    final stderr = process.stderr?.toString() ?? '';
    final output = '$stdout\n$stderr';
    final outcome = classifyAdbConnectOutcome(
      exitCode: process.exitCode,
      stdout: stdout,
      stderr: stderr,
      timedOut: process.isTimeout,
    );

    if (outcome == AdbConnectOutcome.failed) {
      GState.adbConnectionDiagnostic.update((_) => describeAdbConnectFailure(
        endpoint: ADBUtils.deviceName,
        exitCode: process.exitCode,
        stdout: stdout,
        stderr: stderr,
        timedOut: process.isTimeout,
      ));
      if (process.isTimeout) {
        log("ADB connection attempt timed out after 3 seconds");
      } else {
        log("ADB connection attempt failed (exit code: " +
            process.exitCode.toString() + "): " + output);
      }
      status = Env.WSA_INSTALLED
          ? (status == ConnectionStatus.ARRESTED ||
                  status == ConnectionStatus.STARTING)
              && shouldWaitStart
              ? ConnectionStatus.STARTING
              : ConnectionStatus.OFFLINE
          : ConnectionStatus.DISCONNECTED;
    } else if (outcome == AdbConnectOutcome.unauthorized) {
      GState.adbConnectionDiagnostic.update((_) => describeAdbConnectFailure(
        endpoint: ADBUtils.deviceName,
        exitCode: process.exitCode,
        stdout: stdout,
        stderr: stderr,
      ));
      status = ConnectionStatus.UNAUTHORIZED;
    } else {
      GState.adbConnectionDiagnostic.update((_) => "");
      status = ConnectionStatus.CONNECTED;
    }
  }
}

/// Checks if the current environment is a desktop environment.
bool get isDesktop {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}

class Constants {
  //static late final List<String> args;
  static late final String packageFile;
  static late final AppPackage packageType;
  static late final bool installMode;
  static late final IsolateRef<dynamic, APK_READER_FLAGS>? isolate;
}

void main(List<String> arguments) async {
  //int prevTime = DateTime.now().millisecondsSinceEpoch;
  //arguments = [r'C:\Users\Alex\Downloads\firefox-114-1-0.apk'];
  //arguments = [r'C:\Users\Alex\Downloads\Chrome.xapk'];
  

  WidgetsFlutterBinding.ensureInitialized();
  const app = MyApp();
  final wrappedApp = SharedValue.wrapApp(app);
  runApp(wrappedApp);

  AppOptions.init();
  Constants.installMode = arguments.isNotEmpty;
  Constants.packageFile = Constants.installMode ? arguments.first : '';
  Constants.packageType = AppPackageType.fromArguments(arguments);
  Constants.isolate = Constants.installMode ? Constants.packageType.read(arguments.first) : null;

  await flutter_acrylic.Window.initialize();

  WSAPeriodicConnector._checkConnectionStatus();

  flutter_acrylic.Window.hideWindowControls();
  //flutter_acrylic.Window.setEffect(effect: flutter_acrylic.WindowEffect.mica);

  if (isDesktop) {
    doWhenWindowReady(() {
      //log("UI started after ${DateTime.now().millisecondsSinceEpoch - prevTime}");
      final win = appWindow;
      if (!Constants.installMode) {
        win.minSize = const Size(640, 500);
        win.size = const Size(740, 540);
        win.title = appTitle;
      }
      else {
        win.minSize = win.maxSize = win.size = const Size(500, 335);
      }
      win.alignment = Alignment.center;
      win.show();
      late final _SET_VISIBLE = Constants.isolate?.sendFlag(APK_READER_FLAGS.UI_LOADED, true);
      late final Timer uiTimer; uiTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {if (win.isVisible) {
        _SET_VISIBLE;
        uiTimer.cancel();
      }});
    });
  }
}

class _FluentLocalizationsEnglish extends LocalizationsDelegate<FluentLocalizations> {
  const _FluentLocalizationsEnglish();

  @override bool isSupported(Locale locale) => true;
  @override bool shouldReload(_FluentLocalizationsEnglish old) => false;
  @override Future<FluentLocalizations> load(Locale locale) => DefaultFluentLocalizations.load(locale);
  @override String toString() => 'DefaultFluentLocalizations.delegate(en_US)';
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  void setMicaEffect(bool micaEnabled, [bool dark = true]) {
    if (WinVer.isWindows11OrGreater)
      flutter_acrylic.Window.setEffect(effect: micaEnabled ? flutter_acrylic.WindowEffect.mica : flutter_acrylic.WindowEffect.disabled, dark: dark);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the application in a clean, opaque white/light appearance.
    const bool isDark = false;
    setMicaEffect(false, false);

    return ChangeNotifierProvider(
      create: (_) => AppTheme(),
      builder: (context, _) {
        final appTheme = context.watch<AppTheme>();
        return FluentApp(
          title: appTitle,
          themeMode: ThemeMode.light,
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          locale: GState.locale.of(context),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            locale.GlobalMaterialLocalizations.delegate,
            WidgetLocalizationOverrides.delegate,
            //locale.GlobalCupertinoLocalizations.delegate,
            _FluentLocalizationsEnglish(),
          ],
          supportedLocales: LocaleUtils.supportedLocales,
          localeResolutionCallback: LocaleUtils.localeResolutionCallback,
          routes: {'/': (_) => Constants.installMode ? const ApkInstaller() : const MyHomePage()},
          theme: ThemeData(
            buttonTheme: ButtonThemeData(
              defaultButtonStyle: ButtonStyle(
                shadowColor: ButtonState.all(Colors.transparent),
                border: ButtonState.resolveWith((states) {
                  if (isDark) {
                    if (states.isDisabled) return const BorderSide(width: 0.5, color: ColorConst.withOpacity(0xf0f0f0, 0.05));
                    if (states.isNone || (states.isHovering && !states.isPressing)) return const BorderSide(width: 0.5, color: ColorConst.withOpacity(0xf0f0f0, 0.035));
                    else return const BorderSide(width: 0.5, color: ColorConst.withOpacity(0xf0f0f0, 0.07));
                  }
                  else {
                    if (states.isDisabled) return const BorderSide(width: 0.5, color: ColorConst.withOpacity(0x212121, 0.12));
                    if (states.isNone || (states.isHovering && !states.isDisabled && !states.isPressing)) return const BorderSide(width: 0.5, color: ColorConst.withOpacity(0x212121, 0.22));
                    else return const BorderSide(width: 0.5, color: ColorConst.withOpacity(0x212121, 0.07));
                  }
                }),
                backgroundColor: ButtonState.resolveWith((states) {
                  if (isDark) {
                    if (states.isDisabled) return const ColorConst.withOpacity(0xFFFFFF, 0.045);
                    if (states.isPressing) return const ColorConst.withOpacity(0xFFFFFF, 0.03);
                    if (states.isHovering) return const ColorConst.withOpacity(0xFFFFFF, 0.08);
                    return const ColorConst.withOpacity(0xFFFFFF, 0.055);
                  }
                  else {
                    if (states.isDisabled) return const ColorConst.withOpacity(0xf9f9f9, 0.045);
                    if (states.isPressing) return const ColorConst.withOpacity(0xf0f0f0, 0.4);
                    if (states.isHovering) return const ColorConst.withOpacity(0xf9f9f9, 0.65);
                    return const ColorConst.withOpacity(0xFFFFFF, 0.8);
                  }
                })
              ) ,
            ),
            scaffoldBackgroundColor: Colors.white,
            micaBackgroundColor: Colors.white,
            accentColor: appTheme.getColor(false),
            brightness: Brightness.light,
            visualDensity: VisualDensity.standard,
            focusTheme: FocusThemeData(
              glowFactor: is10footScreen() ? 2.0 : 0.0,
            ),
          ),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool value = false;

  int index = 0;

  final colorsController = ScrollController();
  final settingsController = ScrollController();

  @override
  void dispose() {
    colorsController.dispose();
    settingsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    // TODO: implement initState
    /*flutter_acrylic.Acrylic.setEffect(
     effect: flutter_acrylic.AcrylicEffect.acrylic,
     gradientColor: Colors.black.withOpacity(0.2)
    );*/
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final appTheme = context.watch<AppTheme>();
    final theme = FluentTheme.of(context);

    return NavigationView(
      contentShape: RoundedRectangleBorder(
        side: BorderSide(width: 0.3, color: theme.micaBackgroundColor.lerpWith(Colors.black, 0.25)),
        borderRadius: const BorderRadius.only(),
      ),
      appBar: NavigationAppBar(
        // height: !kIsWeb ? appWindow.titleBarHeight : 31.0,
        /*title: () {
          if (kIsWeb) return const Text(appTitle);
          return MoveWindow(
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(appTitle),
            ),
          );
        }(),*/
        actions: kIsWeb
            ? null
            : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1,child: MoveWindow(child: Padding(
                      padding: const EdgeInsets.only(top: 9, left: 13, right: 13), 
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(lang.screen_wsa, style: theme.typography.caption),
                        const SizedBox(width: 10),
                        Text('v$appVersion', style: theme.typography.caption?.copyWith(color: theme.inactiveColor.withAlpha(theme.brightness.isLight ? 0x3F : 0x1B))),
                      ])
                    ))), 
                    const WindowButtons()
                  ],
                )
            /*MoveWindow(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [Spacer(), WindowButtons()],
                ),
              ),*/
      ),
      pane: NavigationPane(
        selected: index,
        onChanged: (i) => setState(() => index = i),
        header: Container(
          height: kOneLineTileHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: material.Row(children: [AnimatedContainer(
            width: 28,
            height: 28,
            duration: const Duration(milliseconds: 750),
            curve: Curves.fastOutSlowIn,
            decoration: const BoxDecoration (
              image: DecorationImage(image:  AssetImage("assets/images/logo.png"))
            ),
          ), const SizedBox(width: 10), Text("WSA PacMan", style: theme.typography.bodyLarge)]),
        ),
        displayMode: appTheme.displayMode,
        indicator: () {
          switch (appTheme.indicator) {
            case NavigationIndicators.end:
              return const EndNavigationIndicator();
            case NavigationIndicators.sticky:
            default:
              return const StickyNavigationIndicator();
          }
        }(),
        items: [
          // It doesn't look good when resizing from compact to open
          // PaneItemHeader(header: Text('User Interaction')),
          ThemablePaneItem(
            icon: const Icon(Mdi.androidDebugBridge),
            title: const Text('WSA'),
            translucent: false,
            forceDisplayMode: appTheme.displayMode
          )
          /*PaneItem(
            icon: Icon(
              appTheme.displayMode == PaneDisplayMode.top
                  ? FluentIcons.more
                  : FluentIcons.more_vertical,
            ),
            title: const Text('Others'),
          ),*/
        ],
        footerItems: [
          PaneItemSeparator(),
          ThemablePaneItem(
            icon: const Icon(FluentIcons.settings),
            title: Text(lang.screen_settings),
            translucent: false,
            forceDisplayMode: appTheme.displayMode
          ),
        ],
      ),
      content: NavigationBody(index: index, children: [
        const ScreenWSA(),
        //const Others(),
        ScreenSettings(controller: settingsController),
      ]),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({Key? key}) : super(key: key);
  static Color windowButtonAlphaColor(ThemeData style, Set<ButtonStates> states) {
    if (style.brightness == Brightness.light) {
      if (states.isPressing) return Colors.black.withOpacity(0.075);
      if (states.isHovering) return Colors.black.withOpacity(0.11);
      return Colors.transparent;
    } else {
      if (states.isPressing) return Colors.white.withOpacity(0.03);
      if (states.isHovering) return Colors.white.withOpacity(0.06);
      return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasFluentTheme(context));
    assert(debugCheckHasFluentLocalizations(context));
    final ThemeData theme = FluentTheme.of(context);

    final buttonColors = WindowButtonColors(
      iconNormal: theme.inactiveColor,
      iconMouseDown: theme.inactiveColor,
      iconMouseOver: theme.inactiveColor,
      //Fixed button colors
      mouseOver: windowButtonAlphaColor(theme, {ButtonStates.hovering}),
      mouseDown: windowButtonAlphaColor(theme, {ButtonStates.pressing}),
    );
    final closeButtonColors = WindowButtonColors(
      mouseOver: Colors.red,
      mouseDown: Colors.red.dark,
      iconNormal: theme.inactiveColor,
      iconMouseOver: Colors.red.basedOnLuminance(),
      iconMouseDown: Colors.red.dark.basedOnLuminance(),
    );
    return Row(children: [
      Tooltip(
        message: FluentLocalizations.of(context).minimizeWindowTooltip,
        child: MinimizeWindowButton(colors: buttonColors),
      ),
      Tooltip(
        message: FluentLocalizations.of(context).restoreWindowTooltip,
        child: WindowButton(
          colors: buttonColors,
          iconBuilder: (context) {
            if (appWindow.isMaximized) {
              return RestoreIcon(color: context.iconColor);
            }
            return MaximizeIcon(color: context.iconColor);
          },
          onPressed: appWindow.maximizeOrRestore,
        ),
      ),
      Tooltip(
        message: FluentLocalizations.of(context).closeWindowTooltip,
        child: CloseWindowButton(colors: closeButtonColors),
      ),
    ]);
  }
}
