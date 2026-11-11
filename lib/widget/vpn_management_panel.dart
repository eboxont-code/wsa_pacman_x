import 'package:fluent_ui/fluent_ui.dart';
import 'package:mdi/mdi.dart';
import 'package:wsa_pacman/global_state.dart';
import 'package:wsa_pacman/utils/vpn_support.dart';
import 'package:wsa_pacman/utils/wsa_utils.dart';
import 'fluent_card.dart';

/// Provider-neutral WSA VPN management.
///
/// PacMan discovers Android packages declaring VpnService and launches their
/// own UI. It does not create tunnels, handle credentials, grant consent, or
/// infer a connected state from incomplete system diagnostics.
class VpnManagementPanel extends StatefulWidget {
  const VpnManagementPanel({
    Key? key,
    required this.isConnected,
    required this.ipAddress,
    required this.port,
  }) : super(key: key);

  final bool isConnected;
  final String ipAddress;
  final int port;

  @override
  State<VpnManagementPanel> createState() => _VpnManagementPanelState();
}

class _VpnManagementPanelState extends State<VpnManagementPanel> {
  bool _isSearching = false;
  bool _hasSearched = false;
  List<VpnProvider> _providers = const [];
  String? _error;
  String? _notice;

  Future<void> _findVpnApps() async {
    if (!widget.isConnected || _isSearching) return;
    setState(() {
      _isSearching = true;
      _error = null;
      _notice = null;
    });

    try {
      final providers = await WSAUtils.discoverVpnApps(
        ipAddress: widget.ipAddress,
        port: widget.port,
      );
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _hasSearched = true;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.wsa_vpn_settings_failed;
        _hasSearched = true;
        _isSearching = false;
      });
    }
  }

  Future<void> _openVpnSettings() async {
    if (!widget.isConnected) return;
    try {
      final result = await WSAUtils.launchVpnSettings(
        ipAddress: widget.ipAddress,
        port: widget.port,
      );
      if (!mounted) return;
      if (result.exitCode != 0) {
        setState(() {
          _error = AppLocalizations.of(context)!.wsa_vpn_settings_failed;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.wsa_vpn_settings_failed;
      });
    }
  }

  Future<void> _openProvider(VpnProvider provider) async {
    if (!widget.isConnected) return;
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      final result = await WSAUtils.launchVpnApp(
        ipAddress: widget.ipAddress,
        port: widget.port,
        packageName: provider.packageName,
      );
      final output = '${result.stdout ?? ''}\n${result.stderr ?? ''}';
      final normalizedOutput = output.toLowerCase();
      final failed = result.exitCode != 0 ||
          normalizedOutput.contains('no activity found') ||
          normalizedOutput.contains('error type 3') ||
          normalizedOutput.contains('unable to resolve');
      if (!mounted) return;
      setState(() {
        if (failed) {
          _error = AppLocalizations.of(context)!.wsa_vpn_launch_failed;
        } else {
          _notice = provider.packageName;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.wsa_vpn_launch_failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.wsa_vpn_apps_header,
          style: theme.typography.bodyLarge,
        ),
        const SizedBox(height: 6),
        Text(lang.wsa_vpn_apps_description),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Button(
                onPressed: widget.isConnected && !_isSearching
                    ? _findVpnApps
                    : null,
                child: Text(
                  _isSearching
                      ? lang.wsa_vpn_searching
                      : lang.wsa_vpn_find_apps,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: widget.isConnected ? _openVpnSettings : null,
              child: Text(lang.wsa_manage_vpn),
            ),
          ],
        ),
        if (!widget.isConnected) ...[
          const SizedBox(height: 10),
          Text(lang.wsa_vpn_connect_first),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(color: theme.accentColor),
          ),
        ],
        if (_notice != null) ...[
          const SizedBox(height: 10),
          Text(_notice!),
        ],
        if (_hasSearched && _providers.isEmpty && _error == null) ...[
          const SizedBox(height: 10),
          Text(lang.wsa_vpn_no_apps),
        ],
        for (final provider in _providers) ...[
          const SizedBox(height: 6),
          FluentCard(
            leading: const Icon(Mdi.vpn, size: 23),
            content: Text(provider.packageName),
            isButton: true,
            onPressed: widget.isConnected
                ? () {
                    _openProvider(provider);
                  }
                : null,
          ),
        ],
        const SizedBox(height: 8),
        Text(lang.wsa_vpn_scope_note),
      ],
    );
  }
}
