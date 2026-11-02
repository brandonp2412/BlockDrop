import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../multiplayer/direct_join_invite.dart';
import '../multiplayer/multiplayer_manager.dart';
import '../multiplayer/wifi_direct.dart';
import 'multiplayer_qr_scanner_screen.dart';

/// Optional Android P2P network setup; BlockDrop still plays over direct TCP.
class MultiplayerWifiDirectScreen extends StatefulWidget {
  final MultiplayerManager manager;
  final WifiDirectController? controller;

  const MultiplayerWifiDirectScreen({
    super.key,
    required this.manager,
    this.controller,
  });

  @override
  State<MultiplayerWifiDirectScreen> createState() =>
      _MultiplayerWifiDirectScreenState();
}

class _MultiplayerWifiDirectScreenState
    extends State<MultiplayerWifiDirectScreen> {
  late final WifiDirectController _wifi;
  final _joinCode = TextEditingController();
  Timer? _refresh;
  String? _error;
  bool _directSession = false;

  @override
  void initState() {
    super.initState();
    _wifi = widget.controller ?? WifiDirectController();
    _wifi.addListener(_update);
    _wifi.onGroupLost = () {
      if (_directSession &&
          widget.manager.state != MultiplayerState.discovering) {
        widget.manager.backToDiscovery();
      }
      if (mounted) setState(() => _error = 'Wi-Fi Direct group disconnected.');
    };
    unawaited(_wifi.initialize());
    _refresh = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _wifi.onGroupLost = null;
    _wifi.removeListener(_update);
    if (widget.controller == null) _wifi.dispose();
    _refresh?.cancel();
    _joinCode.dispose();
    super.dispose();
  }

  Future<void> _host() async {
    setState(() => _error = null);
    if (!await _wifi.host() || !mounted) return;
    try {
      await widget.manager.startHosting();
      _directSession = true;
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Could not start TCP listener: $error');
      await _wifi.disconnect();
    }
  }

  Future<void> _joinPeer(WifiDirectPeer peer) async {
    setState(() => _error = null);
    if (await _wifi.joinPeer(peer) && mounted) {
      _directSession = true;
      setState(() {});
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const MultiplayerQrScannerScreen(),
    ));
    if (!mounted || code == null) return;
    _joinCode.text = code;
    await _join();
  }

  Future<void> _join() async {
    final ip = _wifi.state.groupOwnerIp;
    if (!_wifi.state.connected || _wifi.state.groupOwner || ip == null) {
      setState(() => _error = 'Connect to the host Wi-Fi Direct group first.');
      return;
    }
    try {
      final code = DirectJoinInvite.fromUri(_joinCode.text.trim());
      if (code.expiresAt?.isBefore(DateTime.now()) ?? false) {
        throw const FormatException('Host pairing code expired.');
      }
      // The authenticated token and port come from the host QR; the actual
      // route must use Android's currently connected P2P group owner address.
      final invite = DirectJoinInvite(
        host: ip,
        port: code.port,
        token: code.token,
        version: code.version,
        displayName: code.displayName,
        expiresAt: code.expiresAt,
      )..validate();
      await widget.manager.joinHost(invite, hostName: invite.displayName);
      if (!mounted) return;
      if (widget.manager.state == MultiplayerState.inviting ||
          widget.manager.state == MultiplayerState.inLobby) {
        Navigator.of(context).pop();
      } else {
        setState(
            () => _error = 'TCP join failed; verify the host IP and port.');
      }
    } catch (error) {
      if (mounted)
        setState(
            () => _error = 'Invalid or unreachable host invitation: $error');
    }
  }

  Widget _ownerInvitation() {
    final address = _wifi.state.groupOwnerIp;
    if (address == null || widget.manager.hostingPort == null) {
      return const Text('Waiting for Android to report the group owner IPv4…');
    }
    final invite = widget.manager.hostingInvite(address);
    final expired = invite.expiresAt?.isBefore(DateTime.now()) ?? false;
    final code = invite.toUri().toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Group ready. Share this QR with the joining device.'),
        const SizedBox(height: 12),
        if (!expired)
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: code, size: 224),
            ),
          )
        else
          const Text('The pairing code expired. Generate a new one.'),
        const SizedBox(height: 12),
        SelectableText('P2P host: $address:${invite.port}'),
        if (!expired) SelectableText(code),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: expired
                  ? null
                  : () => Clipboard.setData(ClipboardData(text: code)),
              icon: const Icon(Icons.copy),
              label: const Text('Copy code'),
            ),
            OutlinedButton(
              onPressed: () => setState(widget.manager.refreshPairingToken),
              child: const Text('Refresh code'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _wifi.state;
    final isGuest = state.connected && !state.groupOwner;
    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Direct · optional')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
                'Android-only fallback when ordinary Wi-Fi cannot connect two players. This creates a local group; BlockDrop still uses authenticated TCP and requires host approval.'),
            const SizedBox(height: 12),
            if (!Platform.isAndroid || !state.supported)
              const Text(
                  'Wi-Fi Direct is unsupported here. Use QR or manual IP on standard Wi-Fi.'),
            if (state.supported && !state.wifiEnabled)
              const Text('Wi-Fi is off. Turn Wi-Fi on in Android settings.'),
            if (state.supported && !state.permissionGranted)
              const Text(
                  'Nearby-device permission will be requested when you start.'),
            if (state.supported && state.wifiEnabled) ...[
              const SizedBox(height: 12),
              if (!state.connected) ...[
                FilledButton.icon(
                  onPressed: _wifi.busy ? null : _host,
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Host a Wi-Fi Direct group'),
                ),
                OutlinedButton.icon(
                  onPressed: _wifi.busy ? null : _wifi.discover,
                  icon: const Icon(Icons.radar),
                  label: const Text('Discover Wi-Fi Direct peers'),
                ),
                for (final peer in state.peers)
                  ListTile(
                    title:
                        Text(peer.name.isEmpty ? 'Nearby device' : peer.name),
                    subtitle: Text(peer.address),
                    trailing: const Icon(Icons.link),
                    onTap: _wifi.busy ? null : () => _joinPeer(peer),
                  ),
              ],
              if (state.connected && state.groupOwner) _ownerInvitation(),
              if (isGuest) ...[
                Text(
                    'Connected to group owner ${state.groupOwnerIp}. Scan or paste its BlockDrop code to request a TCP match.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan host QR'),
                ),
                TextField(
                  key: const Key('wifi-direct-join-code'),
                  controller: _joinCode,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Host blockdrop://join code',
                  ),
                ),
                FilledButton(
                  key: const Key('wifi-direct-join'),
                  onPressed: _join,
                  child: const Text('Join host over TCP'),
                ),
              ],
              if (_wifi.busy) ...[
                const LinearProgressIndicator(),
                Text(_wifi.operation ?? 'Waiting for Wi-Fi Direct…'),
              ],
              OutlinedButton(
                onPressed: () async {
                  await _wifi.disconnect();
                  _directSession = false;
                },
                child: Text(_wifi.busy ? 'Cancel' : 'Disconnect Wi-Fi Direct'),
              ),
            ],
            if (_wifi.error != null)
              Text(_wifi.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            const Text(
                'Requires compatible physical Android devices. Waydroid may not implement Wi-Fi Direct. QR cannot bypass firewalls, client isolation or NAT; traffic inside BlockDrop remains JSON over TCP.'),
          ],
        ),
      ),
    );
  }
}
