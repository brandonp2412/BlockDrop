import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../multiplayer/lan_network.dart';
import '../multiplayer/multiplayer_manager.dart';

/// Presents the current local TCP listener as a scannable invitation.
class MultiplayerHostScreen extends StatefulWidget {
  final MultiplayerManager manager;
  final Future<LanAddress?> Function()? detectLan;

  const MultiplayerHostScreen({
    super.key,
    required this.manager,
    this.detectLan,
  });

  @override
  State<MultiplayerHostScreen> createState() => _MultiplayerHostScreenState();
}

class _MultiplayerHostScreenState extends State<MultiplayerHostScreen> {
  LanAddress? _lan;
  bool _loading = true;
  bool _networkChanged = false;
  String? _error;
  Timer? _refreshTimer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_onManagerChange);
    unawaited(_refresh(regenerate: false));
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_checkNetwork()),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    widget.manager.removeListener(_onManagerChange);
    super.dispose();
  }

  void _onManagerChange() {
    if (!mounted) return;
    if (widget.manager.state == MultiplayerState.invited ||
        widget.manager.state == MultiplayerState.inLobby) {
      Navigator.of(context).pop();
    } else {
      setState(() {});
    }
  }

  Future<LanAddress?> _detect() =>
      widget.detectLan?.call() ?? LanNetwork.detect();

  Future<void> _checkNetwork() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final detected = await _detect();
      if (!mounted) return;
      final changed = detected?.ip != _lan?.ip ||
          detected?.prefixLength != _lan?.prefixLength;
      setState(() {
        if (changed) {
          _lan = detected;
          _networkChanged = true;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _networkChanged = true);
    } finally {
      _checking = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _refresh({required bool regenerate}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.manager.hostingPort == null) {
        await widget.manager.startHosting();
      } else if (regenerate) {
        widget.manager.refreshPairingToken();
      }
      final detected = await _detect();
      if (!mounted) return;
      setState(() {
        _lan = detected;
        _networkChanged = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not start the local host. Check your network and retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Join code copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lan = _lan;
    final expires = widget.manager.pairingExpiresAt;
    final validTime = expires != null && expires.isAfter(DateTime.now());
    final available = widget.manager.hostingPort != null &&
        widget.manager.pairingToken != null;
    final showQr = lan != null && available && !_networkChanged && validTime;
    final code =
        showQr ? widget.manager.hostingInvite(lan.ip).toUri().toString() : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Host game'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Invite a player', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Scan on another device that can reach this local network. '
              'No account or Internet service is needed.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(_error!, style: TextStyle(color: cs.error))
            else if (lan == null)
              Text(
                'No physical Wi-Fi or Ethernet IPv4 address detected. '
                'Connect to a LAN, then refresh.',
                style: TextStyle(color: cs.error),
              )
            else if (_networkChanged)
              Text(
                'Your LAN address changed. Regenerate the invitation.',
                style: TextStyle(color: cs.error),
              )
            else if (!validTime)
              Text(
                'This pairing code expired. Regenerate it to host again.',
                style: TextStyle(color: cs.error),
              )
            else if (code != null) ...[
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: QrImageView(
                      key: const Key('host-qr'),
                      data: code,
                      version: QrVersions.auto,
                      size: 252,
                      backgroundColor: Colors.white,
                      semanticsLabel: 'BlockDrop local join invitation QR code',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Scan to join',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 18),
            if (lan != null)
              SelectableText(
                'LAN address: ${lan.ip}/${lan.prefixLength}',
                key: const Key('host-lan-address'),
                style: theme.textTheme.titleMedium,
              ),
            if (widget.manager.hostingPort != null)
              SelectableText(
                'TCP port: ${widget.manager.hostingPort}',
                style: theme.textTheme.bodyLarge,
              ),
            if (expires != null)
              Text(
                validTime
                    ? 'Pairing expires at ${TimeOfDay.fromDateTime(expires).format(context)}'
                    : 'Pairing code expired',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            if (code != null) ...[
              const Text('Copyable join code'),
              const SizedBox(height: 6),
              SelectableText(
                code,
                key: const Key('host-join-code'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('copy-join-code'),
                onPressed: () => _copy(code),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy join code'),
              ),
            ],
            if (lan == null && widget.manager.pairingToken != null) ...[
              const Text('Pairing token (address unavailable)'),
              SelectableText(widget.manager.pairingToken!),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('refresh-invite'),
              onPressed: _loading ? null : () => _refresh(regenerate: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh address & regenerate code'),
            ),
            const SizedBox(height: 14),
            Text(
              'QR transfers an IP, TCP port and temporary token only. '
              'It cannot bypass firewalls, Wi-Fi client isolation or NAT. '
              'TCP traffic is not encrypted.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
