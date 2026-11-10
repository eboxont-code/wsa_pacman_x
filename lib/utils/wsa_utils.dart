import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'package:wsa_pacman/global_state.dart';
import 'package:wsa_pacman/main.dart';
import 'package:wsa_pacman/windows/win_io.dart';
import 'package:wsa_pacman/windows/win_pkg.dart';
import 'wsa_settings_launcher.dart';
import 'vpn_support.dart';
import '../utils/string_utils.dart';
import '../utils/regexp_utils.dart';

class WSAUtils {
  static bool launch([String? param]) => WinIO.run(ShellOp.OPEN, "shell:appsFolder\\${Env.WSA_INFO.familyName}!${Env.WSA_INFO.clientID}", param);
  static bool launchApp(String package) {
    final launched = launch("/launch wsa://$package");
    // Launching an Android app hides only the PacMan manager so the newly
    // launched Android window remains visible. A user-initiated minimize or
    // close is handled natively as a request to hide the whole Android workspace.
    // Temporary APK-installer windows keep their existing close behavior.
    if (launched && isDesktop && !Constants.installMode) {
      appWindow.hide();
    }
    return launched;
  }
  static bool launchSettings() => launchApp("com.android.settings");

  /// Discovers installed packages that declare an Android VpnService.
  ///
  /// PackageManager performs the query inside WSA, so this works for any
  /// provider that registers the standard android.net.VpnService action.
  /// The provider app still owns connection setup and Android consent.
  static Future<List<VpnProvider>> discoverVpnApps({
    required String ipAddress,
    required int port,
  }) async {
    final result = await ADBUtils.shellToAddress(
      ipAddress,
      port,
      'cmd package query-services --brief --components -a android.net.VpnService',
    );
    if (result.exitCode != 0) {
      final output = [
        result.stderr?.toString() ?? '',
        result.stdout?.toString() ?? '',
      ].where((value) => value.trim().isNotEmpty).join(' ').trim();
      throw StateError(output.isEmpty
          ? 'Android Package Manager could not query VPN services (exit code ${result.exitCode}).'
          : output);
    }
    return parseVpnServiceQuery(result.stdout?.toString() ?? '');
  }

  /// Opens the launch activity of a discovered Android VPN provider.
  ///
  /// Package names are validated before they are included in the ADB shell
  /// command. The app must expose a launcher activity to be opened this way.
  static Future<ProcessResult> launchVpnApp({
    required String ipAddress,
    required int port,
    required String packageName,
  }) {
    if (!isSafeAndroidPackageName(packageName)) {
      return Future.error(ArgumentError.value(
        packageName,
        'packageName',
        'Invalid Android package name',
      ));
    }
    return ADBUtils.shellToAddress(
      ipAddress,
      port,
      'am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p $packageName',
    );
  }

  /// Opens Android's system VPN settings inside WSA.
  ///
  /// The VPN client remains responsible for its connection, credentials and
  /// first-use consent. This does not create a VPN tunnel or change Windows
  /// desktop networking.
  static Future<ProcessResult> launchVpnSettings({
    required String ipAddress,
    required int port,
  }) async {
    final vpnSettings = await ADBUtils.shellToAddress(
      ipAddress,
      port,
      'am start -a android.settings.VPN_SETTINGS',
    );
    final output =
        '${vpnSettings.stdout ?? ''}\n${vpnSettings.stderr ?? ''}'
            .toLowerCase();
    final couldNotResolveVpnSettings = vpnSettings.exitCode != 0 ||
        output.contains('unable to resolve') ||
        output.contains('error type 3') ||
        output.contains('no activity found');
    if (!couldNotResolveVpnSettings) return vpnSettings;

    // Some WSA images do not expose the VPN-specific settings intent.
    // Fall back to Android Settings so the user can navigate manually.
    return ADBUtils.shellToAddress(
      ipAddress,
      port,
      'am start com.android.settings/.Settings',
    );
  }
  static bool launchDeveloperSettings() => launch("/deeplink wsa-client://developer-settings");

  /// Opens the installed Windows Subsystem for Android Settings app.
  ///
  /// Resolve its AUMID from the Start Apps catalog instead of hard-coding a
  /// version-specific application ID. This only opens Settings; it does not
  /// modify Developer Mode or any Android debugging preference.
  static bool launchWsaSettings() {
    const command = r"""
$entries = @(Get-StartApps | Where-Object {
  $_.AppID -like 'MicrosoftCorporationII.WindowsSubsystemForAndroid_*!*'
})
$entry = $entries | Where-Object { $_.Name -match '(?i)settings' } | Select-Object -First 1
if (-not $entry -and $entries.Count -eq 1) { $entry = $entries[0] }
if ($entry) {
  [Console]::Out.Write($entry.AppID)
  exit 0
}
exit 2
""";

    try {
      final result = Process.runSync(
        Env.POWERSHELL,
        [
          "-NoLogo",
          "-NoProfile",
          "-NonInteractive",
          "-Command",
          command,
        ],
      );
      if (result.exitCode != 0) return false;

      final appId = parseWsaSettingsAppId(result.stdout?.toString() ?? '');
      if (appId == null) return false;

      return WinIO.run(ShellOp.OPEN, "shell:AppsFolder\\$appId", null);
    } catch (_) {
      return false;
    }
  }
  static bool launchSystem() => launchApp("android.system");
  static bool shutdown() => launch("/shutdown");
  static bool modifyApp(String package) => launch("/modify $package");
  static bool launchPartial() => launch("/partiallyrunning");
  //launch("/jump");    // No idea what this does
  //launch("/deeplink wsa-client://legal-settings");    // Legal settings, pretty useless stuff
}

class WSAPkgInfo extends WinPkgInfo {
  late final String clientID;

  WSAPkgInfo.fromSystemPath(String systemPath) : super.fromSystemPath(systemPath);

  @override void parseManifestExtras(String manifest) {
    String? clientInfo = RegExp('<\\s*Application${REGEX_XML_NOCLOSE}Executable\\s*=\\s*${REGEX_QUOTED_PATTERN((c)=>"[^$c>]*WsaClient.exe")}$REGEX_XML_NOCLOSE', caseSensitive: false, multiLine: true, dotAll: true)
      .firstMatch(manifest)?.group(0);
    clientID = clientInfo?.find('Id\\s*=\\s*($REGEX_XML_QUOTED)', 1)?.unquoted ?? "App";
  }
}

class _TimeoutProcessResult extends ProcessResult {
  _TimeoutProcessResult() : super(-1, -1, null, null);
}

extension ProcessResultTimeout on ProcessResult {
  bool get isTimeout => this is _TimeoutProcessResult;
}

extension ADBUtils on Future<ProcessResult> {
  Future<ProcessResult> defaultError() => onError((error, stackTrace) => ProcessResult(-1, -1, null, null));
  Future<ProcessResult> processTimeout(Duration duration) =>
    timeout(duration, onTimeout: () => Future.value(_TimeoutProcessResult()));

  static String get deviceName => '${GState.ipAddress.$}:${GState.androidPort.$}';
  static String _toName(String ipAddress, int port) => '$ipAddress:$port';
  static String get adbPath => '${Env.TOOLS_DIR}\\adb.exe';

  static Future<ProcessResult> _command(List<String> args, {String? workDir}) => Process.run(adbPath, args, workingDirectory: workDir);
  static Future<ProcessResult> command(String command, {String? param, String? workDir}) => _command([command, if (param != null) param], workDir: workDir);
  static Future<ProcessResult> commandWSA(String command, String? Function(String device) param, {String? workDir}) => ADBUtils.command(command, param: param(deviceName), workDir: workDir);

  static Future<ProcessResult> _withDevice(String device, String command, {List<String>? args, String? workDir}) => _command(['-s', device, command, if (args != null) ...args], workDir: workDir);
  static Future<ProcessResult> withDevice(String device, String command, {String? param, String? workDir}) => _command(['-s', device, command, if (param != null) param], workDir: workDir);
  static Future<ProcessResult> withAddress(String ipAddress, int port, String command, {String? param, String? workDir}) => withDevice(_toName(ipAddress, port), command, param: param, workDir: workDir);
  static Future<ProcessResult> withWSA(String command, {String? param, String? workDir}) => withDevice(deviceName, command, param: param, workDir: workDir);

  static Future<ProcessResult> devices({bool long = false}) => command('devices', param: long ? '-l' : null);

  static Future<ProcessResult> disconnect(String device) => command('disconnect', param: device);
  static Future<ProcessResult> disconnectAddress(String ipAddress, int port) => disconnect(_toName(ipAddress, port));
  static Future<ProcessResult> disconnectWSA() => disconnect(deviceName);

  static Future<ProcessResult> connect(String device) => command('connect', param: device);
  static Future<ProcessResult> connectAddress(String ipAddress, int port) => connect(_toName(ipAddress, port));
  static Future<ProcessResult> connectWSA() => connect(deviceName);

  static Future<ProcessResult> shell(String device, String command) => withDevice(device, 'shell', param: command);
  static Future<ProcessResult> shellToAddress(String ipAddress, int port, String command) => shell(_toName(ipAddress, port), command);
  static Future<ProcessResult> shellToWSA(String command) => shell(deviceName, command);

  static Future<ProcessResult> push(String device, String inPath, String outPath, {String? workDir}) => _withDevice(device, 'push', args: [inPath, outPath], workDir: workDir);
  static Future<ProcessResult> pushToAddress(String ipAddress, int port, String inPath, String outPath, {String? workDir}) => push(_toName(ipAddress, port), inPath, outPath);
  static Future<ProcessResult> pushToWSA(String inPath, String outPath, {String? workDir}) => push(deviceName, inPath, outPath);

  static Future<ProcessResult> _installWithOptions(String device, String apk, {List<String>? options, String? workDir}) => _withDevice(device, 'install', args: [if (options != null) ...options, apk], workDir: workDir);
  static Future<ProcessResult> install(String device, String apk, {bool downgrade = false, String? workDir}) => _installWithOptions(device, apk, options: [if (downgrade) '-r', if (downgrade) '-d'], workDir: workDir);
  static Future<ProcessResult> installToAddress(String ipAddress, int port, String apk, {bool downgrade = false, String? workDir}) => install(_toName(ipAddress, port), apk, downgrade: downgrade, workDir: workDir);
  static Future<ProcessResult> installToWSA(String apk, {bool downgrade = false, String? workDir}) => install(deviceName, apk, downgrade: downgrade, workDir: workDir);

  static Future<ProcessResult> _installMultipleWithOptions(String device, List<String> apkFiles, {List<String>? options, String? workDir}) => _withDevice(device, 'install-multiple', args: [if (options != null) ...options, ...apkFiles], workDir: workDir);
  static Future<ProcessResult> installMultiple(String device, List<String> apkFiles, {bool downgrade = false, String? workDir}) => _installMultipleWithOptions(device, apkFiles, options: [if (downgrade) '-r', if (downgrade) '-d'], workDir: workDir);
  static Future<ProcessResult> installMultipleToAddress(String ipAddress, int port, List<String> apkFiles, {bool downgrade = false, String? workDir}) => installMultiple(_toName(ipAddress, port), apkFiles, downgrade: downgrade, workDir: workDir);
  static Future<ProcessResult> installMultipleToWSA(List<String> apkFiles, {bool downgrade = false, String? workDir}) => installMultiple(deviceName, apkFiles, downgrade: downgrade, workDir: workDir);
}