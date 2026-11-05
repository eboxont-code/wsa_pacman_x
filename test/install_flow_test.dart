import 'package:flutter_test/flutter_test.dart';
import 'package:wsa_pacman/utils/install_flow.dart';

void main() {
  group('shouldAutoLaunchWsa', () {
    test('direct APK open starts WSA on a fresh install with preference off', () {
      expect(
        shouldAutoLaunchWsa(
          launchAlreadyAttempted: false,
          isConnected: false,
          installMode: true,
          autoStartPreference: false,
        ),
        isTrue,
      );
    });

    test('direct APK open does not launch WSA twice', () {
      expect(
        shouldAutoLaunchWsa(
          launchAlreadyAttempted: true,
          isConnected: false,
          installMode: true,
          autoStartPreference: false,
        ),
        isFalse,
      );
    });

    test('does not launch WSA when already connected', () {
      expect(
        shouldAutoLaunchWsa(
          launchAlreadyAttempted: false,
          isConnected: true,
          installMode: true,
          autoStartPreference: false,
        ),
        isFalse,
      );
    });

    test('manager mode respects the optional autostart preference', () {
      expect(
        shouldAutoLaunchWsa(
          launchAlreadyAttempted: false,
          isConnected: false,
          installMode: false,
          autoStartPreference: false,
        ),
        isFalse,
      );
      expect(
        shouldAutoLaunchWsa(
          launchAlreadyAttempted: false,
          isConnected: false,
          installMode: false,
          autoStartPreference: true,
        ),
        isTrue,
      );
    });
  });

  group('canInstallPackage', () {
    test('enables install only when connected and package type is known', () {
      expect(
        canInstallPackage(isConnected: true, hasKnownInstallType: true),
        isTrue,
      );
    });

    test('keeps install disabled while ADB is offline', () {
      expect(
        canInstallPackage(isConnected: false, hasKnownInstallType: true),
        isFalse,
      );
    });

    test('keeps install disabled while package inspection is incomplete', () {
      expect(
        canInstallPackage(isConnected: true, hasKnownInstallType: false),
        isFalse,
      );
    });
  });

  group('shouldRefreshInstallType', () {
    test('retries an unknown install type after ADB reconnects', () {
      expect(
        shouldRefreshInstallType(
          isConnected: true,
          hasUnknownInstallType: true,
          hasPackage: true,
          hasVersionCode: true,
          refreshInProgress: false,
        ),
        isTrue,
      );
    });

    test('does not query while ADB is offline', () {
      expect(
        shouldRefreshInstallType(
          isConnected: false,
          hasUnknownInstallType: true,
          hasPackage: true,
          hasVersionCode: true,
          refreshInProgress: false,
        ),
        isFalse,
      );
    });

    test('waits until package metadata is ready', () {
      expect(
        shouldRefreshInstallType(
          isConnected: true,
          hasUnknownInstallType: true,
          hasPackage: false,
          hasVersionCode: true,
          refreshInProgress: false,
        ),
        isFalse,
      );
    });

    test('does not overlap an install-type query', () {
      expect(
        shouldRefreshInstallType(
          isConnected: true,
          hasUnknownInstallType: true,
          hasPackage: true,
          hasVersionCode: true,
          refreshInProgress: true,
        ),
        isFalse,
      );
    });

    test('does not repeat a successful install-type inspection', () {
      expect(
        shouldRefreshInstallType(
          isConnected: true,
          hasUnknownInstallType: false,
          hasPackage: true,
          hasVersionCode: true,
          refreshInProgress: false,
        ),
        isFalse,
      );
    });
  });
}
