import 'package:flutter_test/flutter_test.dart';
import 'package:wsa_pacman/utils/wsa_settings_launcher.dart';

void main() {
  group('parseWsaSettingsAppId', () {
    test('accepts the WSA Settings AppUserModelId', () {
      expect(
        parseWsaSettingsAppId(
          'MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App',
        ),
        'MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App',
      );
    });

    test('trims command output', () {
      expect(
        parseWsaSettingsAppId(
          '  MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App\r\n',
        ),
        'MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App',
      );
    });

    test('rejects an unrelated application id', () {
      expect(parseWsaSettingsAppId('Microsoft.WindowsCalculator_8wekyb3d8bbwe!App'), isNull);
    });

    test('rejects empty and multi-line output', () {
      expect(parseWsaSettingsAppId(''), isNull);
      expect(
        parseWsaSettingsAppId(
          'MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App\nextra',
        ),
        isNull,
      );
    });

    test('rejects malformed application ids', () {
      expect(parseWsaSettingsAppId('MicrosoftCorporationII.WindowsSubsystemForAndroid_!App'), isNull);
      expect(
        parseWsaSettingsAppId(
          'MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App!Other',
        ),
        isNull,
      );
      expect(
        parseWsaSettingsAppId(
          'MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbdbe!App with spaces',
        ),
        isNull,
      );
    });
  });
}
