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
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();
  if (details.isEmpty) {
    return 'Could not connect to $endpoint (ADB exit code $exitCode).';
  }

  final conciseDetails = details.length > 240
      ? '${details.substring(0, 237)}...'
      : details;
  return 'ADB could not connect to $endpoint: $conciseDetails';
}
