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
    r'(password|passphrase|mnemonic|seed phrase|private[_ -]?key|authorization|bearer|access[_ -]?token|refresh[_ -]?token|api[_ -]?key|token)',
    caseSensitive: false,
  );
  final sensitiveAssignment = RegExp(
    r"""((?:password|passphrase|mnemonic|seed phrase|private[_ -]?key|authorization|bearer|access[_ -]?token|refresh[_ -]?token|api[_ -]?key)\s*[:=]\s*)[^\r\n,;]+""",
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

/// Sanitizes and bounds one command result so a large Package Manager
/// dump cannot push the more useful process-exit and permission logs out of
/// the diagnostic report.
String limitMystNodesDiagnosticSection(
  String value, {
  int maxCharacters = 2500,
}) {
  final safe = sanitizeMystNodesDiagnosticText(value);
  if (safe.length <= maxCharacters) return safe;
  final marker = '\n[Section truncated at $maxCharacters characters.]';
  final available = maxCharacters > marker.length
      ? maxCharacters - marker.length
      : 0;
  return safe.substring(0, available) + marker;
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
    r'(network\.mysterium\.provider|MystNodes|VpnService|VpnManager|VpnDialogs|VpnConfirm|com\.android\.vpndialogs|ConfirmDialog|BIND_VPN_SERVICE|android\.net\.VpnService|AndroidRuntime|FATAL EXCEPTION|Fatal signal|ActivityTaskManager|ActivityManager|PackageManager|Permission Denial|SecurityException|ForegroundService|RemoteServiceException|NodeService|NodeImpl|LaunchViewModel|missing_vpn_permission|Process .* has died|Killing .*network\.mysterium)',
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

/// Keeps the user/restriction source labels around VPN policy state.
///
/// Android's user dump may show base restrictions separately from device
/// policy local/global restrictions. Keeping the surrounding labels prevents
/// a restriction from being incorrectly attributed to an administrator.
String selectMystNodesRestrictionContext(
  String dumpOutput, {
  int maxLines = 100,
}) {
  final lines = dumpOutput.split(RegExp(r'\r?\n'));
  final anchor = RegExp(
    r'(no_config_vpn|DISALLOW_CONFIG_VPN|base restrictions|user restrictions|device policy local restrictions|device policy global restrictions|restriction source|UserInfo)',
    caseSensitive: false,
  );
  final selected = <int>{};

  for (var i = 0; i < lines.length; i++) {
    if (!anchor.hasMatch(lines[i])) continue;
    final start = i > 5 ? i - 5 : 0;
    final end = (i + 10 < lines.length) ? i + 10 : lines.length - 1;
    for (var j = start; j <= end; j++) {
      selected.add(j);
    }
  }

  final indices = selected.toList()..sort();
  final bounded = indices.length > maxLines
      ? indices.sublist(0, maxLines)
      : indices;
  if (bounded.isEmpty) {
    return '[No VPN restriction source labels were visible in the Android user dump.]';
  }
  return sanitizeMystNodesDiagnosticText(
    bounded.map((index) => lines[index]).join('\n'),
  );
}

/// Extracts only the installed package's service/component section and nearby
/// VPN declarations from its Package Manager dump. Empty output is not proof
/// that a service is absent because Android dump formats vary by build.
String selectMystNodesPackageServiceMetadata(
  String packageDump, {
  int maxLines = 100,
}) {
  final lines = packageDump.split(RegExp(r'\r?\n'));
  final anchor = RegExp(
    r'(Services:|Service Resolver Table|android\.net\.VpnService|BIND_VPN_SERVICE|VpnService|NodeService|ServiceRecord|ServiceInfo)',
    caseSensitive: false,
  );
  final selected = <int>{};

  for (var i = 0; i < lines.length; i++) {
    if (!anchor.hasMatch(lines[i])) continue;
    final start = i > 4 ? i - 4 : 0;
    final end = (i + 12 < lines.length) ? i + 12 : lines.length - 1;
    for (var j = start; j <= end; j++) {
      selected.add(j);
    }
  }

  final indices = selected.toList()..sort();
  final bounded = indices.length > maxLines
      ? indices.sublist(0, maxLines)
      : indices;
  if (bounded.isEmpty) {
    return '[No service/component declaration lines were visible in the MystNodes package dump; this alone does not prove the APK has no VPN service.]';
  }
  return sanitizeMystNodesDiagnosticText(
    bounded.map((index) => lines[index]).join('\n'),
  );
}

/// Finds the base APK path returned by `pm path` without trusting arbitrary
/// command output as a local or remote path.
bool isSafeMystNodesBaseApkPath(String path) =>
    path.startsWith('/data/app/') &&
    path.endsWith('/base.apk') &&
    !path.contains('..') &&
    !RegExp(r'[\s\x00]').hasMatch(path);

String? extractMystNodesBaseApkPath(String packagePathOutput) {
  for (final rawLine in packagePathOutput.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (!line.startsWith('package:')) continue;
    final path = line.substring('package:'.length).trim();
    if (isSafeMystNodesBaseApkPath(path)) return path;
  }
  return null;
}

/// Summarises the merged AndroidManifest.xml extracted from the installed
/// MystNodes base APK by AAPT2. The output deliberately distinguishes a
/// successfully parsed manifest with no service elements from an AAPT2 error
/// or output format that could not be recognised.
String selectMystNodesApkManifestServiceEntries(
  String xmlTreeOutput, {
  int maxLines = 140,
}) {
  final lines = xmlTreeOutput.split(RegExp(r'\r?\n'));
  final hasManifest = lines.any(
    (line) => RegExp(r'^\s*E:\s+manifest(?:\s|$)', caseSensitive: false)
        .hasMatch(line),
  );
  final hasApplication = lines.any(
    (line) => RegExp(r'^\s*E:\s+application(?:\s|$)', caseSensitive: false)
        .hasMatch(line),
  );
  if (!hasManifest || !hasApplication) {
    return '[AAPT2 output did not contain a recognisable manifest and application tree; service declarations are inconclusive.]';
  }

  final serviceHeader = RegExp(
    r'^(\s*)E:\s+service(?:\s|$)',
    caseSensitive: false,
  );
  final serviceStarts = <int>[];
  for (var i = 0; i < lines.length; i++) {
    if (serviceHeader.hasMatch(lines[i])) serviceStarts.add(i);
  }
  if (serviceStarts.isEmpty) {
    return 'AAPT2 successfully parsed the installed MystNodes base APK AndroidManifest.xml.\n'
        'Declared Android service elements: 0.\n'
        'No <service> element is declared in this base APK manifest.';
  }

  final selected = <int>{};
  final serviceSibling = RegExp(
    r'^\s*E:\s+(?:activity|activity-alias|meta-data|provider|receiver|service)(?:\s|$)',
    caseSensitive: false,
  );
  for (final start in serviceStarts) {
    final header = serviceHeader.firstMatch(lines[start])!;
    final indent = header.group(1)!.length;
    selected.add(start);
    for (var i = start + 1; i < lines.length; i++) {
      final sibling = serviceSibling.firstMatch(lines[i]);
      if (sibling != null && sibling.group(0)!.indexOf('E:') <= indent) {
        break;
      }
      selected.add(i);
    }
  }

  final allServiceText = selected.toList()..sort();
  final serviceText = allServiceText.map((index) => lines[index]).join('\n');
  final hasVpnAction = serviceText.contains('android.net.VpnService');
  final hasBindingPermission = serviceText.contains('android.permission.BIND_VPN_SERVICE');
  final bounded = allServiceText.length > maxLines
      ? allServiceText.sublist(0, maxLines)
      : allServiceText;
  final detail = sanitizeMystNodesDiagnosticText(
    bounded.map((index) => lines[index]).join('\n'),
  );
  return 'AAPT2 successfully parsed the installed MystNodes base APK AndroidManifest.xml.\n'
      'Declared Android service elements: ${serviceStarts.length}.\n'
      'A declared service contains the android.net.VpnService action: ${hasVpnAction ? 'yes' : 'no'}.\n'
      'A declared service uses android.permission.BIND_VPN_SERVICE: ${hasBindingPermission ? 'yes' : 'no'}.\n'
      'Service declarations:\n$detail';
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
    ..writeln('Privacy: local report only. The base APK is temporarily copied for manifest inspection, then deleted; it is not uploaded.')
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
  if (report.length <= 28000) return report;
  return '${report.substring(0, 27970)}\n[Report truncated at 28,000 characters.]';
}
