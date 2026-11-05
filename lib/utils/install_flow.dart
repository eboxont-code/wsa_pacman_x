/// Returns whether the APK installer should make its one automatic WSA
/// launch attempt. Direct-open install mode always starts WSA on a fresh
/// installer, independent of the manager's optional preference.
bool shouldAutoLaunchWsa({
  required bool launchAlreadyAttempted,
  required bool isConnected,
  required bool installMode,
  required bool autoStartPreference,
}) {
  return !launchAlreadyAttempted &&
      !isConnected &&
      (installMode || autoStartPreference);
}

/// Installation is enabled only after ADB is connected and package inspection
/// produced a supported install type.
bool canInstallPackage({
  required bool isConnected,
  required bool hasKnownInstallType,
}) {
  return isConnected && hasKnownInstallType;
}
