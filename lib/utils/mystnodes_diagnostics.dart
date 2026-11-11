/// Read-only diagnostic helpers for the selected MystNodes WSA app.
///
/// Reports are generated locally from ADB command output. They are not sent
/// anywhere by PacMan. Sensitive-looking log lines and common credential
/// assignments are redacted before the report is shown or copied.
const String mystNodesPackageName = 'network.mysterium.provider';

class MystNodesDiagnosticCommandResult {
  const MystNodesDiagnosticCommandResult({
    required this.label,
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final String label;
  final int exitCode;
  final String stdout;
  final String stderr;
}

String sanitizeMystNodesDiagnosticText(String value) {
  final result = <String>[];
  final sensitiveLine = RegExp(
    r'(password|passphrase|mnemonic|seed phrase|private[_ -]?key|authorization|bearer|access[_ -]?token|refresh[_ -]?token|api[_ -]?key)',
    caseSensitive: false,
  );
  final sensitiveAssignment = RegExp(
    r"""((?:password|passphrase|mnemonic|seed phrase|private[_ -]?key|authorization|bearer|access[_ -]?token|refresh[_ -]?token|api[_ -]?key)\s*[:=]\s*)["']?[^\s"',;]+""",
    caseSensitive: false,
  );
  final urlQuery = RegExp(r'(https?://[^\s?]+)\?[^\s]+');
  final email = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );

  for (final rawLine in value.split(RegExp(r'\r?\n'))) {
    if (rawLine.trim().isEmpty) continue;
    if (sensitiveLine.hasMatch(rawLine) &&
        !sensitiveAssignment.hasMatch(rawLine)) {
      result.add('[REDACTED: potentially sensitive log line]');
      continue;
    }

    var line = rawLine.replaceAllMapped(
      sensitiveAssignment,
      (match) => '${match.group(1)}[REDACTED]',
    );
    line = line.replaceAllMapped(
      urlQuery,
      (match) => '${match.group(1)}?[REDACTED]',
    );
    line = line.replaceAll(email, '[REDACTED_EMAIL]');
    if (line.length > 600) {
      line = '${line.substring(0, 597)}...';
    }
    result.add(line);
  }

  return result.join('\n');
}

/// Selects recent Android logcat lines relevant to MystNodes, Android VPN
/// consent, package/service resolution and app/activity termination. Nearby
/// lines are included for stack traces and ActivityResult context.
String selectMystNodesRelevantLogLines(
  String logOutput, {
  int maxLines = 120,
}) {
  final lines = logOutput.split(RegExp(r'\r?\n'));
  final anchor = RegExp(
    r'(network\.mysterium\.provider|MystNodes|VpnService|VpnManager|VpnDialogs|BIND_VPN_SERVICE|android\.net\.VpnService|AndroidRuntime|FATAL EXCEPTION|Fatal signal|ActivityTaskManager|ActivityManager|PackageManager|Permission Denial|SecurityException|ForegroundService|RemoteServiceException|NodeService|NodeImpl|LaunchViewModel|missing_vpn_permission|Process .* has died|Killing .*network\.mysterium)',
    caseSensitive: false,
  );
  final selected = <int>{};

  for (var i = 0; i < lines.length; i++) {
    if (!anchor.hasMatch(lines[i])) continue;
    final start = i > 2 ? i - 2 : 0;
    final end = (i + 8 < lines.length) ? i + 8 : lines.length - 1;
    for (var j = start; j <= end; j++) {
      selected.add(j);
    }
  }

  final indices = selected.toList()..sort();
  final bounded = indices.length > maxLines
      ? indices.sublist(indices.length - maxLines)
      : indices;
  if (bounded.isEmpty) {
    return '[No matching MystNodes, VPN, Android permission or app-lifecycle log lines were found in the recent buffer.]';
  }

  return sanitizeMystNodesDiagnosticText(
    bounded.map((index) => lines[index]).join('\n'),
  );
}

String buildMystNodesDiagnosticReport({
  required DateTime capturedAt,
  required List<MystNodesDiagnosticCommandResult> commands,
}) {
  final buffer = StringBuffer()
    ..writeln('WSA PacMan — MystNodes diagnostic report')
    ..writeln('Captured: ${capturedAt.toUtc().toIso8601String()}')
    ..writeln('Target package: $mystNodesPackageName')
    ..writeln('Mode: read-only; existing Android logs were not cleared.')
    ..writeln('Privacy: this report is local. Review it before sharing.')
    ..writeln();

  for (final command in commands) {
    buffer
      ..writeln('=== ${command.label} ===')
      ..writeln('Exit code: ${command.exitCode}');
    final stdout = sanitizeMystNodesDiagnosticText(command.stdout).trim();
    final stderr = sanitizeMystNodesDiagnosticText(command.stderr).trim();
    buffer
      ..writeln('STDOUT:')
      ..writeln(stdout.isEmpty ? '(empty)' : stdout)
      ..writeln('STDERR:')
      ..writeln(stderr.isEmpty ? '(empty)' : stderr)
      ..writeln();
  }

  final report = buffer.toString();
  if (report.length <= 24000) return report;
  return '${report.substring(0, 23970)}\n[Report truncated at 24,000 characters.]';
}
