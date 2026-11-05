/// Raised when an ADB operation exits unsuccessfully.
class AdbCommandFailure implements Exception {
  final String operation;
  final int exitCode;
  final String output;

  const AdbCommandFailure(this.operation, this.exitCode, this.output);

  @override
  String toString() {
    final details = output.isEmpty ? 'no output' : output;
    return 'ADB $operation failed (exit code $exitCode): $details';
  }
}

/// Throws when an ADB command fails instead of silently treating it as done.
void requireAdbCommandSuccess({
  required String operation,
  required int exitCode,
  Object? stdout,
  Object? stderr,
}) {
  if (exitCode == 0) return;

  final output = [
    if (stdout != null && stdout.toString().trim().isNotEmpty)
      stdout.toString().trim(),
    if (stderr != null && stderr.toString().trim().isNotEmpty)
      stderr.toString().trim(),
  ].join('\\n');

  throw AdbCommandFailure(operation, exitCode, output);
}
