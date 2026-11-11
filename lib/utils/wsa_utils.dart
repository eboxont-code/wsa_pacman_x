import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'package:wsa_pacman/global_state.dart';
import 'package:wsa_pacman/main.dart';
import 'package:wsa_pacman/windows/win_io.dart';
import 'package:wsa_pacman/windows/win_pkg.dart';
import 'wsa_settings_launcher.dart';
import 'vpn_support.dart';
import 'mystnodes_diagnostics.dart';
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
    final output = result.stdout?.toString() ?? '';
    final providers = parseVpnServiceQuery(output);
    final explicitlyEmpty = RegExp(
      r'no services found|no matching services',
      caseSensitive: false,
    ).hasMatch(output);
    if (providers.isEmpty && !explicitlyEmpty) {
      throw FormatException(
        'Android Package Manager returned output PacMan could not interpret. '
        'Use the MystNodes diagnostic report to inspect the raw response.',
        output,
      );
    }
    return providers;
  }

  /// Captures a local, read-only diagnostic report for the selected MystNodes
  /// package. It never clears logcat, changes settings or uploads the report.
  static Future<String> captureMystNodesDiagnostic({
    required String ipAddress,
    required int port,
  }) async {
    final results = <MystNodesDiagnosticCommandResult>[];

    Future<String?> capture(
      String label,
      String command, {
      bool filterLogs = false,
      bool filterRestrictionContext = false,
      bool filterPackageServices = false,
      int maxOutputCharacters = 2500,
    }) async {
      try {
        final result = await ADBUtils.shellToAddress(ipAddress, port, command);
        final rawStdout = result.stdout?.toString() ?? '';
        final selectedOutput = filterLogs
            ? selectMystNodesRelevantLogLines(rawStdout, maxLines: 140)
            : filterRestrictionContext
                ? selectMystNodesRestrictionContext(rawStdout)
                : filterPackageServices
                    ? selectMystNodesPackageServiceMetadata(rawStdout)
                    : rawStdout;
        results.add(MystNodesDiagnosticCommandResult(
          label: label,
          exitCode: result.exitCode,
          stdout: limitMystNodesDiagnosticSection(
            selectedOutput,
            maxCharacters: maxOutputCharacters,
          ),
          stderr: limitMystNodesDiagnosticSection(
            result.stderr?.toString() ?? '',
            maxCharacters: 1200,
          ),
        ));
        return result.exitCode == 0 ? rawStdout : null;
      } catch (error) {
        results.add(MystNodesDiagnosticCommandResult(
          label: label,
          exitCode: -1,
          stderr: error.toString(),
        ));
        return null;
      }
    }

    await capture('Android release', 'getprop ro.build.version.release');
    await capture('Android SDK level', 'getprop ro.build.version.sdk');
    await capture('Android CPU ABI', 'getprop ro.product.cpu.abi');
    await capture('Android supported ABIs', 'getprop ro.product.cpu.abilist');
    final apkPathOutput = await capture(
      'Installed MystNodes APK paths',
      'pm path $mystNodesPackageName',
    );
    final remoteBaseApk = extractMystNodesBaseApkPath(apkPathOutput ?? '');
    if (remoteBaseApk == null) {
      results.add(const MystNodesDiagnosticCommandResult(
        label: 'Installed MystNodes APK manifest inspection',
        exitCode: -1,
        stderr: 'Could not identify a safe base.apk path from Package Manager output; manifest inspection was skipped.',
      ));
    } else {
      Directory? temporaryDirectory;
      try {
        temporaryDirectory = await Directory.systemTemp.createTemp(
          'wsa-pacman-mystnodes-',
        );
        final localApk = File(
          '${temporaryDirectory.path}${Platform.pathSeparator}mystnodes-base.apk',
        );
        final pull = await ADBUtils.pullToAddress(
          ipAddress,
          port,
          remoteBaseApk,
          localApk.path,
        );
        final localApkExists = await localApk.exists();
        if (pull.exitCode != 0 || !localApkExists) {
          results.add(MystNodesDiagnosticCommandResult(
            label: 'Installed MystNodes APK merged manifest inspection (local temporary copy)',
            exitCode: pull.exitCode == 0 ? -1 : pull.exitCode,
            stderr: limitMystNodesDiagnosticSection(
              '${pull.stderr ?? ''} ${pull.stdout ?? ''} APK copy was not available; no manifest was inspected.',
              maxCharacters: 1600,
            ),
          ));
        } else {
          final manifest = await Process.run(
            '${Env.TOOLS_DIR}aapt2.exe',
            [
              'dump',
              'xmltree',
              '--file',
              'AndroidManifest.xml',
              localApk.path,
            ],
          );
          final manifestOutput = manifest.stdout?.toString() ?? '';
          results.add(MystNodesDiagnosticCommandResult(
            label: 'Installed MystNodes base APK merged AndroidManifest.xml service declarations (AAPT2)',
            exitCode: manifest.exitCode,
            stdout: limitMystNodesDiagnosticSection(
              manifest.exitCode == 0
                  ? selectMystNodesApkManifestServiceEntries(manifestOutput)
                  : '[AAPT2 could not inspect the installed base APK manifest; service declarations are inconclusive.]',
              maxCharacters: 6500,
            ),
            stderr: limitMystNodesDiagnosticSection(
              manifest.stderr?.toString() ?? '',
              maxCharacters: 1600,
            ),
          ));
        }
      } catch (_) {
        results.add(const MystNodesDiagnosticCommandResult(
          label: 'Installed MystNodes APK merged manifest inspection (local temporary copy)',
          exitCode: -1,
          stderr: 'The local APK manifest inspection could not complete. No MystNodes data or settings were changed.',
        ));
      } finally {
        if (temporaryDirectory != null && await temporaryDirectory.exists()) {
          try {
            await temporaryDirectory.delete(recursive: true);
          } catch (error) {
            results.add(MystNodesDiagnosticCommandResult(
              label: 'Temporary MystNodes APK cleanup',
              exitCode: -1,
              stderr: 'PacMan could not remove its temporary APK inspection folder automatically. No app data was changed.',
            ));
          }
        }
      }
    }
    await capture(
      'Android system VPN consent package APK paths',
      'pm path com.android.vpndialogs',
    );
    await capture(
      'Android VPN consent component registration and enabled state',
      "dumpsys package com.android.vpndialogs | grep -i -C 4 -E 'enabled|ConfirmDialog|VpnConfirm|versionName'",
      maxOutputCharacters: 3500,
    );
    await capture(
      'Android VPN consent package UID (read-only)',
      'cmd package list packages -U com.android.vpndialogs',
      maxOutputCharacters: 800,
    );
    await capture(
      'Installed MystNodes package UID (read-only)',
      'cmd package list packages -U $mystNodesPackageName',
      maxOutputCharacters: 800,
    );
    await capture(
      'Android VPN consent package identity and CONTROL_VPN permission (read-only)',
      "dumpsys package com.android.vpndialogs | grep -i -C 3 -E 'userId=|sharedUser|CONTROL_VPN|grantedPermissions|privateFlags|SYSTEM|PRIVILEGED'",
      maxOutputCharacters: 2400,
    );

    await capture(
      'Android VPN consent activity resolution',
      'cmd package resolve-activity --brief -n com.android.vpndialogs/.ConfirmDialog',
      maxOutputCharacters: 1500,
    );
    await capture(
      'Existing Android Always-on VPN package (read-only)',
      'settings get secure always_on_vpn_app',
      maxOutputCharacters: 500,
    );
    await capture(
      'Android user VPN restriction source and context (read-only)',
      'dumpsys user',
      filterRestrictionContext: true,
      maxOutputCharacters: 3000,
    );
    await capture(
      'Android device and profile policy owners (read-only)',
      'cmd device_policy list-owners',
      maxOutputCharacters: 1500,
    );
    await capture(
      'Android device policy VPN restriction context (read-only)',
      "dumpsys device_policy | grep -i -C 5 -E 'Device Owner:|Profile Owner|admin=ComponentInfo|no_config_vpn|vpn'",
      maxOutputCharacters: 3500,
    );
    await capture(
      'Installed MystNodes package version and identity metadata',
      "dumpsys package $mystNodesPackageName | grep -i -C 4 -E 'versionName|versionCode|primaryCpuAbi|secondaryCpuAbi|signing|signatures|firstInstallTime|installSource'",
      maxOutputCharacters: 3500,
    );
    await capture(
      'Complete MystNodes service and VPN component declarations (read-only)',
      'dumpsys package $mystNodesPackageName',
      filterPackageServices: true,
      maxOutputCharacters: 5000,
    );
    await capture(
      'Device-wide Android VPN service query (supported Package Manager syntax)',
      'cmd package query-services --brief --components -a android.net.VpnService',
    );
    await capture(
      'Recent MystNodes process exit history',
      'dumpsys activity exit-info $mystNodesPackageName',
      maxOutputCharacters: 3000,
    );
    await capture(
      'Recent MystNodes VPN-consent, policy and app-lifecycle logs (filtered)',
      r'''logcat -d -v threadtime -t 4000 | grep -i -E 'network\.mysterium\.provider|MystNodes|VpnService|VpnManager|VpnDialogs|VpnConfirm|com\.android\.vpndialogs|ConfirmDialog|BIND_VPN_SERVICE|no_config_vpn|DISALLOW_CONFIG_VPN|AndroidRuntime|FATAL EXCEPTION|Permission Denial|SecurityException|DevicePolicyManager|ActivityTaskManager|ActivityManager|ActivityResult|resultCode' | tail -n 180''',
      maxOutputCharacters: 7000,
    );

    return buildMystNodesDiagnosticReport(
      capturedAt: DateTime.now(),
      commands: results,
    );
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

  /// Opens the VPN management screen inside Android in WSA.
  ///
  /// Use an explicit Android Settings component instead of the implicit
  /// android.settings.VPN_SETTINGS intent. WSA can bridge that implicit action
  /// to Windows Settings, which is outside the requested Android-only scope.
  /// The explicit component keeps the launch inside the WSA Android container.
  ///
  /// The provider app and Android remain responsible for VPN consent,
  /// Always-on VPN, lockdown and tunnel lifecycle.
  static Future<ProcessResult> launchVpnSettings({
    required String ipAddress,
    required int port,
  }) async {
    final vpnSettings = await ADBUtils.shellToAddress(
      ipAddress,
      port,
      buildAndroidVpnSettingsCommand(),
    );
    final output =
        '${vpnSettings.stdout ?? ''}\n${vpnSettings.stderr ?? ''}'
            .toLowerCase();
    final couldNotOpenAndroidVpnSettings = vpnSettings.exitCode != 0 ||
        output.contains('unable to resolve') ||
        output.contains('error type 3') ||
        output.contains('no activity found') ||
        output.contains('does not exist');

    if (!couldNotOpenAndroidVpnSettings) return vpnSettings;

    // Keep the fallback explicitly inside Android. Never fall back to a
    // Windows URI, protocol handler or Windows VPN settings page.
    return ADBUtils.shellToAddress(
      ipAddress,
      port,
      buildAndroidSettingsFallbackCommand(),
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
  static Future<ProcessResult> pullToAddress(
    String ipAddress,
    int port,
    String remotePath,
    String localPath,
  ) {
    if (!isSafeMystNodesBaseApkPath(remotePath)) {
      return Future.error(ArgumentError.value(
        remotePath,
        'remotePath',
        'Only an installed Android base APK path can be pulled for local manifest inspection',
      ));
    }
    return _withDevice(
      _toName(ipAddress, port),
      'pull',
      args: [remotePath, localPath],
    );
  }
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