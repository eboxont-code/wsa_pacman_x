import 'package:flutter_test/flutter_test.dart';
import 'package:wsa_pacman/utils/mystnodes_diagnostics.dart';

void main() {
  group('limitMystNodesDiagnosticSection', () {
    test('sanitizes and bounds large command output', () {
      final limited = limitMystNodesDiagnosticSection(
        'token=private-value\n' + List.filled(2000, 'A').join(),
        maxCharacters: 500,
      );

      expect(limited.length, lessThanOrEqualTo(500));
      expect(limited, isNot(contains('private-value')));
      expect(limited, contains('Section truncated at 500 characters'));
    });
  });

  group('MystNodes diagnostic log selection', () {
    test('keeps VPN, MystNodes and Android activity lifecycle context', () {
      final trailingNoise = List.generate(
        15,
        (index) => '01-01 10:00:1${index.toString().padLeft(2, '0')}.000 I/OtherApp: trailing noise $index',
      ).join('\n');
      final filtered = selectMystNodesRelevantLogLines(
        '01-01 10:00:00.000 I/OtherApp: nearby context\n'
        '01-01 10:00:01.000 I/ActivityTaskManager: START cmp=com.android.vpndialogs/.ConfirmDialog\n'
        '01-01 10:00:02.000 I/MystNodes: launching VPN consent\n'
        '01-01 10:00:03.000 W/ActivityManager: Finishing activity network.mysterium.provider/.MainActivity\n'
        '$trailingNoise',
      );

      expect(filtered, contains('com.android.vpndialogs'));
      expect(filtered, contains('ConfirmDialog'));
      expect(filtered, contains('MystNodes'));
      expect(filtered, contains('network.mysterium.provider'));
      expect(filtered, isNot(contains('trailing noise 14')));
    });

    test('explains when no matching Android log lines are present', () {
      final filtered = selectMystNodesRelevantLogLines(
        'I/OtherApp: nothing about this package\n',
      );

      expect(filtered, contains('No matching MystNodes'));
    });

    test('bounds the selected log lines', () {
      final source = List.generate(
        200,
        (index) => 'I/ActivityManager: process $index network.mysterium.provider',
      ).join('\n');

      final filtered = selectMystNodesRelevantLogLines(source, maxLines: 20);
      expect(filtered.split('\n').length, lessThanOrEqualTo(20));
    });
  });

  group('MystNodes restriction and package metadata selection', () {
    test('preserves labels needed to attribute a VPN user restriction', () {
      final selected = selectMystNodesRestrictionContext(
        'UserInfo{0:Owner}\n'
        '  Base restrictions:\n'
        '    no_config_vpn\n'
        '  Device policy local restrictions:\n'
        '    null\n'
        '  Device policy global restrictions:\n'
        '    null\n',
      );

      expect(selected, contains('Base restrictions:'));
      expect(selected, contains('no_config_vpn'));
      expect(selected, contains('Device policy local restrictions:'));
      expect(selected, contains('Device policy global restrictions:'));
    });

    test('keeps declared VPN service and binding permission lines', () {
      final selected = selectMystNodesPackageServiceMetadata(
        'Package [network.mysterium.provider]\n'
        '  Services:\n'
        '    network.mysterium.provider/.NodeService:\n'
        '      permission=android.permission.BIND_VPN_SERVICE\n'
        '      Action: android.net.VpnService\n'
        '  Receivers:\n',
      );

      expect(selected, contains('NodeService'));
      expect(selected, contains('BIND_VPN_SERVICE'));
      expect(selected, contains('android.net.VpnService'));
      expect(selected, contains('Receivers:'));
    });

    test('does not claim a missing service when the dump has no matching lines', () {
      final selected = selectMystNodesPackageServiceMetadata(
        'Package [network.mysterium.provider]\n'
        '  versionName=5.2.2\n',
      );

      expect(selected, contains('does not prove the APK has no VPN service'));
    });
  });

  group('Installed MystNodes APK manifest inspection', () {
    test('extracts only a base APK path from Package Manager output', () {
      expect(
        extractMystNodesBaseApkPath(
          'package:/data/app/~~safe/network.mysterium.provider-abc/base.apk\\n',
        ),
        '/data/app/~~safe/network.mysterium.provider-abc/base.apk',
      );
      expect(
        extractMystNodesBaseApkPath(
          'package:/data/app/~~safe/network.mysterium.provider-abc/split_config.x86_64.apk\\n',
        ),
        isNull,
      );
      expect(
        extractMystNodesBaseApkPath(
          'package:/data/app/../../private/base.apk\\n',
        ),
        isNull,
      );
    });

    test('reports the exact VPN service declaration from a parsed manifest', () {
      final report = selectMystNodesApkManifestServiceEntries(
        'N: android=http://schemas.android.com/apk/res/android\\n'
        '  E: manifest (line=1)\\n'
        '    E: application (line=8)\\n'
        '      E: service (line=12)\\n'
        '        A: android:name(0x01010003)=\"network.mysterium.node.core.NodeService\"\\n'
        '        A: android:exported(0x01010010)=(type 0x12)0x0\\n'
        '      E: service (line=18)\\n'
        '        A: android:name(0x01010003)=\"network.mysterium.node.vpn.NodeVpnService\"\\n'
        '        A: android:permission(0x01010006)=\"android.permission.BIND_VPN_SERVICE\"\\n'
        '        E: intent-filter (line=20)\\n'
        '          E: action (line=21)\\n'
        '            A: android:name(0x01010003)=\"android.net.VpnService\"\\n'
        '      E: activity (line=30)\\n',
      );

      expect(report, contains('Declared Android service elements: 2'));
      expect(report, contains('android.net.VpnService action: yes'));
      expect(report, contains('BIND_VPN_SERVICE: yes'));
      expect(report, contains('network.mysterium.node.vpn.NodeVpnService'));
    });

    test('only reports no services after confirming a parsed manifest tree', () {
      final noServices = selectMystNodesApkManifestServiceEntries(
        'E: manifest (line=1)\\n'
        '  E: application (line=5)\\n'
        '    E: activity (line=6)\\n',
      );
      final unknown = selectMystNodesApkManifestServiceEntries(
        'Error: could not open AndroidManifest.xml\\n',
      );

      expect(noServices, contains('Declared Android service elements: 0'));
      expect(noServices, contains('No <service> element is declared'));
      expect(unknown, contains('service declarations are inconclusive'));
    });
  });

  group('sanitizeMystNodesDiagnosticText', () {
    test('redacts credential assignments, URL query values and email addresses', () {
      final safe = sanitizeMystNodesDiagnosticText(
        'api_key=secret-value\n'
        'Authorization: Bearer bearer-secret-value\n'
        'Request https://example.test/node?access_token=private-value\n'
        'Contact user@example.test\n'
        'normal package network.mysterium.provider\n',
      );

      expect(safe, isNot(contains('secret-value')));
      expect(safe, isNot(contains('bearer-secret-value')));
      expect(safe, isNot(contains('private-value')));
      expect(safe, isNot(contains('user@example.test')));
      expect(safe, contains('[REDACTED]'));
      expect(safe, contains('[REDACTED_EMAIL]'));
      expect(safe, contains('network.mysterium.provider'));
    });

    test('redacts whole sensitive lines when the value format is unclear', () {
      final safe = sanitizeMystNodesDiagnosticText(
        'Authorization failure with unknown details\n'
        'ordinary ActivityTaskManager message\n',
      );

      expect(safe, isNot(contains('Authorization failure')));
      expect(safe, contains('[REDACTED: potentially sensitive log line]'));
      expect(safe, contains('ActivityTaskManager'));
    });
  });

  group('buildMystNodesDiagnosticReport', () {
    test('labels command results and states that logs were not cleared', () {
      final report = buildMystNodesDiagnosticReport(
        capturedAt: DateTime.utc(2026, 11, 11, 10),
        commands: const [
          MystNodesDiagnosticCommandResult(
            label: 'Installed MystNodes APK paths',
            exitCode: 0,
            stdout: 'package:/data/app/network.mysterium.provider/base.apk',
          ),
          MystNodesDiagnosticCommandResult(
            label: 'VPN service query',
            exitCode: 127,
            stderr: 'cmd: unknown command query-services',
          ),
        ],
      );

      expect(report, contains('Target package: network.mysterium.provider'));
      expect(report, contains('existing Android logs were not cleared'));
      expect(report, contains('Installed MystNodes APK paths'));
      expect(report, contains('Exit code: 127'));
      expect(report, contains('unknown command query-services'));
    });

    test('caps oversized reports', () {
      final report = buildMystNodesDiagnosticReport(
        capturedAt: DateTime.utc(2026, 11, 11),
        commands: List.generate(
          50,
          (index) => MystNodesDiagnosticCommandResult(
            label: 'Command result $index',
            exitCode: 0,
            stdout: List.filled(600, 'A').join(),
          ),
        ),
      );

      expect(report.length, lessThanOrEqualTo(28020));
      expect(report, contains('Report truncated'));
    });
  });
}
