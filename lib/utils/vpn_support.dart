/// Provider-neutral models and parsing for Android VpnService discovery in WSA.
///
/// Android apps expose VPN capability by declaring a service that handles the
/// `android.net.VpnService` intent action. The Android system, not PacMan,
/// remains responsible for VPN consent and tunnel lifecycle.
class VpnProvider {
  const VpnProvider({
    required this.packageName,
    required this.serviceCount,
  });

  final String packageName;
  final int serviceCount;
}

/// Parses `cmd package query-services --brief --components -a
/// android.net.VpnService` output into a unique, sorted provider list.
///
/// Only strict Android component names are accepted. Extra diagnostic text,
/// malformed components and shell metacharacters are ignored.
List<VpnProvider> parseVpnServiceQuery(String output) {
  final serviceCounts = <String, int>{};
  final componentPattern = RegExp(
    r'^\s*([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+)/'
    r'(?:\.[A-Za-z_$][A-Za-z0-9_.$]*|[A-Za-z_][A-Za-z0-9_.$]*)\s*$',
  );

  for (final line in output.split(RegExp(r'\r?\n'))) {
    final match = componentPattern.firstMatch(line);
    if (match == null) continue;
    final packageName = match.group(1)!;
    serviceCounts[packageName] = (serviceCounts[packageName] ?? 0) + 1;
  }

  final providers = serviceCounts.entries
      .map((entry) => VpnProvider(
            packageName: entry.key,
            serviceCount: entry.value,
          ))
      .toList()
    ..sort((a, b) => a.packageName.compareTo(b.packageName));

  return providers;
}

/// Validates a package name before it is included in an ADB shell command.
bool isSafeAndroidPackageName(String value) => RegExp(
      r'^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+$',
    ).hasMatch(value);
