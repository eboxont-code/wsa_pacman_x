/// Validates the AppUserModelId returned by Get-StartApps before using it
/// as a shell:AppsFolder target. Only the installed WSA package is accepted.
String? parseWsaSettingsAppId(String output) {
  final appId = output.trim();
  if (appId.isEmpty || appId.contains(RegExp(r'\\s'))) return null;

  const packagePrefix =
      'MicrosoftCorporationII.WindowsSubsystemForAndroid_';
  final separator = appId.indexOf('!');
  if (!appId.startsWith(packagePrefix) ||
      separator <= packagePrefix.length ||
      separator != appId.lastIndexOf('!') ||
      separator == appId.length - 1) {
    return null;
  }

  final familyName = appId.substring(0, separator);
  final applicationId = appId.substring(separator + 1);
  final validPart = RegExp(r'^[A-Za-z0-9._-]+$');
  if (!validPart.hasMatch(familyName) ||
      !validPart.hasMatch(applicationId)) {
    return null;
  }

  return appId;
}
