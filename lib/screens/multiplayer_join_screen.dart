import 'dart:io';

import 'package:flutter/material.dart';

import '../multiplayer/direct_join_invite.dart';
import '../multiplayer/multiplayer_manager.dart';
import 'multiplayer_qr_scanner_screen.dart';

/// Connects to a player-hosted TCP game without requiring LAN discovery.
class MultiplayerJoinScreen extends StatefulWidget {
  final MultiplayerManager manager;
  final Future<String?> Function(BuildContext context)? scanInvitation;

  const MultiplayerJoinScreen({
    super.key,
    required this.manager,
    this.scanInvitation,
  });

  @override
  State<MultiplayerJoinScreen> createState() => _MultiplayerJoinScreenState();
}

class _MultiplayerJoinScreenState extends State<MultiplayerJoinScreen> {
  final _address = TextEditingController();
  final _port = TextEditingController(text: '45679');
  final _token = TextEditingController();
  final _code = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _port.dispose();
    _token.dispose();
    _code.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  DirectJoinInvite _parseCode(String text) {
    final invite = DirectJoinInvite.fromUri(text.trim());
    if (invite.expiresAt?.isBefore(DateTime.now()) ?? false) {
      throw const FormatException(
          'This pairing code has expired. Ask the host for a fresh one.');
    }
    return invite;
  }

  Future<void> _scan() async {
    final scan = widget.scanInvitation ??
        (context) => Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => const MultiplayerQrScannerScreen(),
              ),
            );
    try {
      final text = await scan(context);
      if (!mounted || text == null) return;
      final invite = _parseCode(text);
      _address.text = invite.host;
      _port.text = invite.port.toString();
      _token.text = invite.token;
      _code.text = text;
      await _join(invite);
    } on FormatException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not open the scanner. Enter the details manually.');
    }
  }

  Future<void> _joinCode() async {
    try {
      await _join(_parseCode(_code.text));
    } on FormatException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _joinManual() async {
    try {
      final invite = DirectJoinInvite(
        host: _address.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 0,
        token: _token.text.trim(),
      )..validate();
      await _join(invite);
    } on FormatException {
      _showError(
          'Enter a valid IPv4 address, port (1–65535), and 48-character pairing token.');
    }
  }

  Future<void> _join(DirectJoinInvite invite) async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await widget.manager.joinHost(invite, hostName: invite.displayName);
      if (!mounted) return;
      if (widget.manager.state == MultiplayerState.inviting ||
          widget.manager.state == MultiplayerState.inLobby) {
        Navigator.of(context).pop();
      } else {
        _showError('Connection failed. Check the host address and firewall.');
      }
    } on StateError {
      _showError('A multiplayer connection is already active.');
    } catch (_) {
      _showError(
          'Could not join. Check the address, port, and pairing details.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanSupported = Platform.isAndroid || Platform.isIOS;
    return Scaffold(
      appBar: AppBar(title: const Text('Join game'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Connect directly to a player hosting BlockDrop. Both devices need a reachable TCP network route.',
            ),
            const SizedBox(height: 20),
            if (scanSupported || widget.scanInvitation != null)
              FilledButton.icon(
                key: const Key('scan-join-qr'),
                onPressed: _connecting ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan host QR code'),
              ),
            if (!scanSupported && widget.scanInvitation == null)
              const Text(
                  'Camera scanning is not available on this platform. Use the join code or manual address.'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('join-code'),
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Paste blockdrop:// join code',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('join-with-code'),
              onPressed: _connecting ? null : _joinCode,
              child: const Text('Join using code'),
            ),
            const SizedBox(height: 20),
            const Text('Or enter details manually',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('join-address'),
              controller: _address,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Host IPv4 address',
                hintText: '192.168.1.20',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('join-port'),
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'TCP port',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('join-token'),
              controller: _token,
              decoration: const InputDecoration(
                labelText: 'Pairing token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('join-manual'),
              onPressed: _connecting ? null : _joinManual,
              icon: const Icon(Icons.link),
              label: const Text('Join by IP'),
            ),
            if (_connecting) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  key: const Key('join-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            const Text(
              'QR shares connection details only. It cannot bypass firewalls, isolated Wi-Fi clients or NAT. TCP traffic is not encrypted.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
