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
  final serviceBlocks = <String>[];
  final serviceSibling = RegExp(
    r'^\s*E:\s+(?:activity|activity-alias|meta-data|provider|receiver|service)(?:\s|$)',
    caseSensitive: false,
  );
  for (final start in serviceStarts) {
    final header = serviceHeader.firstMatch(lines[start])!;
    final indent = header.group(1)!.length;
    final serviceLines = <String>[lines[start]];
    selected.add(start);
    for (var i = start + 1; i < lines.length; i++) {
      final sibling = serviceSibling.firstMatch(lines[i]);
      if (sibling != null && sibling.group(0)!.indexOf('E:') <= indent) {
        break;
      }
      selected.add(i);
      serviceLines.add(lines[i]);
    }
    serviceBlocks.add(serviceLines.join('\n'));
  }

  // Android requires the VPN action and BIND_VPN_SERVICE permission on the
  // same service. Do not combine declarations from unrelated services.
  final hasVpnAction = serviceBlocks.any(
    (service) => service.contains('android.net.VpnService'),
  );
  final hasBindingPermission = serviceBlocks.any(
    (service) => service.contains('android.permission.BIND_VPN_SERVICE'),
  );
  final hasCompleteVpnService = serviceBlocks.any(
    (service) =>
        service.contains('android.net.VpnService') &&
        service.contains('android.permission.BIND_VPN_SERVICE'),
  );
  final allServiceText = selected.toList()..sort();
  final bounded = allServiceText.length > maxLines
      ? allServiceText.sublist(0, maxLines)
      : allServiceText;
  final detail = sanitizeMystNodesDiagnosticText(
    bounded.map((index) => lines[index]).join('\n'),
  );
  return 'AAPT2 successfully parsed the installed MystNodes base APK AndroidManifest.xml.\n'
      'Declared Android service elements: ' + serviceStarts.length.toString() + '.\n'
      'At least one declared service contains the android.net.VpnService action: ' +
      (hasVpnAction ? 'yes' : 'no') + '.\n'
      'At least one declared service uses android.permission.BIND_VPN_SERVICE: ' +
      (hasBindingPermission ? 'yes' : 'no') + '.\n'
      'A single declared service contains both required VPN declarations: ' +
      (hasCompleteVpnService ? 'yes' : 'no') + '.\n'
      'Service declarations:\n$detail';
}

/// Extracts the Android package UID from `pm list packages -U` or
/// Package Manager dump output. Returns null when the output is inconclusive.
int? extractAndroidPackageUid(String output) {
  final patterns = [
    RegExp(r'\buid\s*:\s*(\d+)', caseSensitive: false),
    RegExp(r'\buserId\s*=\s*(\d+)', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(output);
    if (match != null) return int.tryParse(match.group(1)!);
  }
  return null;
}

/// Summarises the read-only report without guessing at an unresolved root cause.
String buildMystNodesDiagnosticAssessment(
  List<MystNodesDiagnosticCommandResult> commands,
) {
  MystNodesDiagnosticCommandResult? findResult(String label) {
    for (final command in commands) {
      if (command.label == label) return command;
    }
    return null;
  }

  final findings = <String>[];
  final manifest = findResult(
    'Installed MystNodes base APK merged AndroidManifest.xml service declarations (AAPT2)',
  );
  final manifestParsed = manifest != null &&
      manifest.exitCode == 0 &&
      manifest.stdout.contains(
        'AAPT2 successfully parsed the installed MystNodes base APK AndroidManifest.xml',
      );

  if (!manifestParsed) {
    findings.add(
      'The installed APK VPN-service check is inconclusive. Do not infer that a service is missing until AAPT2 successfully inspects the merged manifest.',
    );
  } else {
    final completeService = manifest!.stdout.contains(
      'A single declared service contains both required VPN declarations: yes.',
    );
    if (completeService) {
      findings.add(
        'The installed MystNodes APK declares a service with both the Android VPN action and BIND_VPN_SERVICE permission. If Package Manager still finds no VPN service, the manifest and system discovery results need to be reconciled.',
      );
    } else {
      findings.add(
        'The installed MystNodes APK does not declare a single service containing both the android.net.VpnService action and android.permission.BIND_VPN_SERVICE permission. PacMan is therefore correctly excluding it from standard Android VPN-provider discovery. A vendor-confirmed compatible signed APK or vendor-supported alternative is needed; PacMan must not patch or re-sign this APK.',
      );
    }
  }

  final restriction = findResult(
    'Android user VPN restriction source and context (read-only)',
  );
  if (restriction != null &&
      restriction.stdout.toLowerCase().contains('no_config_vpn')) {
    final owners = findResult(
      'Android device and profile policy owners (read-only)',
    );
    final hasNoOwners = owners != null &&
        owners.stdout.toLowerCase().contains('no owners');
    final noLocalPolicy = RegExp(
      r'Device policy local restrictions:\s*(?:none|null)',
      caseSensitive: false,
    ).hasMatch(restriction.stdout);
    final noGlobalPolicy = RegExp(
      r'Device policy global restrictions:\s*(?:none|null)',
      caseSensitive: false,
    ).hasMatch(restriction.stdout);
    if (hasNoOwners && noLocalPolicy && noGlobalPolicy) {
      findings.add(
        'Android also reports no_config_vpn, but this capture found no device/profile owner and no device-policy local or global restriction. The restriction source remains unidentified; do not remove or bypass it based on this evidence.',
      );
    } else {
      findings.add(
        'Android reports no_config_vpn. The available owner/policy evidence does not fully identify its source, so do not remove or bypass it without a separate, evidence-based review.',
      );
    }
  }

  final dialogUidResult = findResult(
    'Android VPN consent package UID (read-only)',
  );
  final mystNodesUidResult = findResult(
    'Installed MystNodes package UID (read-only)',
  );
  final dialogUid = dialogUidResult == null
      ? null
      : extractAndroidPackageUid(dialogUidResult.stdout);
  final mystNodesUid = mystNodesUidResult == null
      ? null
      : extractAndroidPackageUid(mystNodesUidResult.stdout);
  if (dialogUid != null && mystNodesUid != null) {
    if (dialogUid != mystNodesUid) {
      final dialogIdentity = findResult(
        'Android VPN consent package identity and CONTROL_VPN permission (read-only)',
      );
      final identityText = dialogIdentity?.stdout.toLowerCase() ?? '';
      final sharedUser = RegExp(
        r'shareduser(?:id)?\s*[=:]\s*[^\s]+',
        caseSensitive: false,
      ).hasMatch(identityText);
      final controlVpnGrant = RegExp(
        r'CONTROL_VPN\s*:\s*granted=(true|false)',
        caseSensitive: false,
      ).firstMatch(identityText);
      final controlDetail = controlVpnGrant == null
          ? 'This capture did not expose a CONTROL_VPN grant state.'
          : 'CONTROL_VPN is reported ${controlVpnGrant.group(1)!.toLowerCase()} for the dialog package.';
      final sharedDetail = sharedUser
          ? 'A shared-user entry is present in the package dump.'
          : 'No shared-user entry was visible in the package dump.';
      findings.add(
        'The VPN confirmation package UID ($dialogUid) differs from the MystNodes UID ($mystNodesUid). The earlier AppOps package/UID exception is consistent with the confirmation path checking MystNodes while running under the dialog package identity. $sharedDetail $controlDetail Do not change package ownership or bypass Android consent; confirm the installed WSA component identity and permission grant first.',
      );
    } else {
      findings.add(
        'The VPN confirmation package and MystNodes report the same UID ($dialogUid); this capture does not support a distinct-package-UID explanation for the earlier AppOps exception.',
      );
    }
  } else if (dialogUidResult != null || mystNodesUidResult != null) {
    findings.add(
      'The VPN confirmation package and MystNodes UIDs could not both be parsed. The dialog/package identity question remains inconclusive.',
    );
  }

  final logs = findResult(
    'Recent MystNodes VPN-consent, policy and app-lifecycle logs (filtered)',
  );
  if (logs != null) {
    final logText = logs.stdout.toLowerCase();
    if (logText.contains('securityexception') &&
        logText.contains('network.mysterium.provider') &&
        (logText.contains('vpn.isvpnservicepreconsented') ||
            logText.contains('vpnmanagerservice.preparevpn'))) {
      findings.add(
        'The Android logs also contain an AppOps package/UID SecurityException during VPN pre-authorization. This is a separate Android/WSA consent-path failure; the report does not establish why that identity mismatch occurs.',
      );
    }
  }

  if (findings.isEmpty) {
    return 'No conclusive MystNodes compatibility finding could be derived from this capture.';
  }
  return findings.map((finding) => '- ' + finding).join('\n');
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
    ..writeln()
    ..writeln('=== Automated assessment (read-only) ===')
    ..writeln(buildMystNodesDiagnosticAssessment(commands))
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
