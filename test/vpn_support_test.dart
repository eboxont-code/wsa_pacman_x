import 'package:flutter_test/flutter_test.dart';
import 'package:wsa_pacman/utils/vpn_support.dart';

void main() {
  group('parseVpnServiceQuery', () {
    test('parses compact relative and fully qualified service components', () {
      final providers = parseVpnServiceQuery(
        'com.example.vpn/.TunnelService\n'
        'org.example.client/org.example.client.VpnService\n',
      );

      expect(providers.map((provider) => provider.packageName), [
        'com.example.vpn',
        'org.example.client',
      ]);
      expect(providers.map((provider) => provider.serviceCount), [1, 1]);
    });

    test('groups multiple VPN services declared by the same app', () {
      final providers = parseVpnServiceQuery(
        'com.example.vpn/.PrimaryService\n'
        'com.example.vpn/.FallbackService\n'
        'com.example.other/.VpnService\n',
      );

      expect(providers.length, 2);
      expect(providers.first.packageName, 'com.example.other');
      expect(providers.last.packageName, 'com.example.vpn');
      expect(providers.last.serviceCount, 2);
    });

    test('ignores headers, diagnostics and malformed component names', () {
      final providers = parseVpnServiceQuery(
        'Services:\n'
        'No services found\n'
        'com.example.vpn/.TunnelService\n'
        'not a component\n'
        'com.example.vpn/../../bad\n'
        'com.example.vpn/.Bad;touch\n'
        'com.example.vpn/.Bad Service\n',
      );

      expect(providers.length, 1);
      expect(providers.single.packageName, 'com.example.vpn');
    });

    test('returns an empty list when no VPN service is found', () {
      expect(parseVpnServiceQuery('No services found\n'), isEmpty);
      expect(parseVpnServiceQuery(''), isEmpty);
    });

    test('sorts package names deterministically', () {
      final providers = parseVpnServiceQuery(
        'z.example.vpn/.Service\n'
        'a.example.vpn/.Service\n',
      );

      expect(
        providers.map((provider) => provider.packageName),
        ['a.example.vpn', 'z.example.vpn'],
      );
    });
  });

  group('isSafeAndroidPackageName', () {
    test('accepts valid Android package names', () {
      expect(isSafeAndroidPackageName('com.example.vpn'), isTrue);
      expect(isSafeAndroidPackageName('org.example.vpn_client'), isTrue);
    });

    test('rejects shell metacharacters and malformed names', () {
      expect(isSafeAndroidPackageName(''), isFalse);
      expect(isSafeAndroidPackageName('com.example;reboot'), isFalse);
      expect(isSafeAndroidPackageName('com.example && id'), isFalse);
      expect(isSafeAndroidPackageName('com.example.vpn/Service'), isFalse);
      expect(isSafeAndroidPackageName('com'), isFalse);
    });
  });
}
