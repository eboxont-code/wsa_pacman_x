/// Classifies the result of `adb connect` without depending on Flutter or
/// platform-specific process APIs. Kept pure so connection handling can be
/// covered by unit tests.
enum AdbConnectOutcome {
  connected,
  unauthorized,
  failed,
}

AdbConnectOutcome classifyAdbConnectOutcome({
  required int exitCode,
  required String stdout,
  required String stderr,
  bool timedOut = false,
}) {
  if (timedOut) return AdbConnectOutcome.failed;

  final output = '$stdout\n$stderr';
  if (RegExp(
    r'(^|\n)(cannot|failed to) connect\s.*',
    caseSensitive: false,
  ).hasMatch(output)) {
    return AdbConnectOutcome.failed;
  }

  if (RegExp(
    r'(^|\n)(cannot|failed to) authenticate\s.*',
    caseSensitive: false,
  ).hasMatch(output)) {
    return AdbConnectOutcome.unauthorized;
  }

  if (exitCode != 0) return AdbConnectOutcome.failed;
  return AdbConnectOutcome.connected;
}

/// Builds a short, user-visible diagnostic for a failed ADB connection.
/// Output is normalized and capped because ADB may include long platform
/// error messages; the endpoint and useful failure reason are retained.
String describeAdbConnectFailure({
  required String endpoint,
  required int exitCode,
  required String stdout,
  required String stderr,
  bool timedOut = false,
}) {
  if (timedOut) {
    return 'Connection to $endpoint timed out while starting ADB.';
  }

  final details = '$stdout $stderr'
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (details.isEmpty) {
    return 'Could not connect to $endpoint (ADB exit code $exitCode).';
  }

  final conciseDetails = details.length > 240
      ? '${details.substring(0, 237)}...'
      : details;
  return 'ADB could not connect to $endpoint: $conciseDetails';
}


/// ADB endpoint reported by adb devices -l for a WSA device.
class WsaAdbEndpoint {
  const WsaAdbEndpoint({
    required this.host,
    required this.port,
    required this.state,
  });

  final String host;
  final int port;
  final String state;

  String get serial => '$host:$port';
}

bool _isIpv4Address(String value) {
  final parts = value.split('.');
  if (parts.length != 4) return false;
  for (final part in parts) {
    final octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) return false;
  }
  return true;
}

/// Finds a unique WSA endpoint from adb devices -l.
///
/// WSA identifies itself with product/device windows_x86_64. A preferred
/// configured endpoint wins when present. Otherwise, an alternate endpoint is
/// only selected when exactly one WSA device is reported, avoiding accidental
/// switching to a phone or to one of several WSA instances.
WsaAdbEndpoint? findWsaAdbEndpoint(
  String devicesOutput, {
  String? preferredSerial,
}) {
  final candidates = <WsaAdbEndpoint>[];

  for (final line in devicesOutput.split(RegExp(r'\r?\n'))) {
    final match = RegExp(
      r'^\s*(\d{1,3}(?:\.\d{1,3}){3}):(\d+)\s+(device|offline|unauthorized|host)(?:\s+(.*))?\s*$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) continue;

    final host = match.group(1)!;
    final port = int.tryParse(match.group(2)!);
    if (!_isIpv4Address(host) || port == null || port < 1 || port > 65535) {
      continue;
    }

    final metadata = match.group(4) ?? '';
    final isWsa = RegExp(
      r'(^|\s)(product|device):windows_x86_64(\s|$)',
      caseSensitive: false,
    ).hasMatch(metadata) ||
        RegExp(
          r'(^|\s)model:Subsystem_for_Android',
          caseSensitive: false,
        ).hasMatch(metadata);
    if (!isWsa) continue;

    candidates.add(WsaAdbEndpoint(
      host: host,
      port: port,
      state: match.group(3)!.toLowerCase(),
    ));
  }

  if (candidates.isEmpty) return null;

  if (preferredSerial != null) {
    for (final candidate in candidates) {
      if (candidate.serial == preferredSerial) return candidate;
    }
  }

  return candidates.length == 1 ? candidates.single : null;
}
