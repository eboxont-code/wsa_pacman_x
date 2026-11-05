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
