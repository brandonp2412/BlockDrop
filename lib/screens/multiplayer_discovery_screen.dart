import 'dart:io';

import 'package:flutter/material.dart';

import '../multiplayer/multiplayer_manager.dart';
import '../multiplayer/peer.dart';
import '../settings/settings_provider.dart';
import '../widgets/game_decorations.dart';
import 'multiplayer_game_screen.dart';

class MultiplayerDiscoveryScreen extends StatefulWidget {
  final SettingsProvider settings;

  const MultiplayerDiscoveryScreen({super.key, required this.settings});

  @override
  State<MultiplayerDiscoveryScreen> createState() =>
      _MultiplayerDiscoveryScreenState();
}

class _MultiplayerDiscoveryScreenState
    extends State<MultiplayerDiscoveryScreen> {
  late final MultiplayerManager _manager;
  bool _navigatingToGame = false;

  @override
  void initState() {
    super.initState();

    _manager = MultiplayerManager(playerName: _defaultPlayerName());
    _manager.onError = _showError;
    _manager.onInviteReceived = _showInviteDialog;
    _manager.addListener(_onManagerChanged);
    _manager.startDiscovery();
  }

  String _defaultPlayerName() {
    try {
      return Platform.localHostname.split('.').first;
    } catch (_) {
      return 'Player';
    }
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    _manager.dispose();
    super.dispose();
  }

  void _onManagerChanged() {
    if (!mounted) return;
    setState(() {});

    // Navigate to game screen when both sides enter inGame state
    if (_manager.state == MultiplayerState.inGame && !_navigatingToGame) {
      _navigatingToGame = true;
      Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerGameScreen(
            manager: _manager,
            settings: widget.settings,
          ),
        ),
      ).then((closeDiscovery) {
        _navigatingToGame = false;
        if (!mounted) return;
        // Restore our own error handler now that the game screen is gone
        _manager.onError = _showError;
        if (closeDiscovery == true) {
          Navigator.of(context).pop();
        } else {
          _manager.backToDiscovery();
        }
      });
    }
  }

  void _showFirewallDialog() {
    final style = widget.settings.style;
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: styledDialogShape(style, cs),
        title: const Text('Windows Firewall'),
        content: const Text(
          'Windows Firewall may be blocking other players from connecting to '
          'this device.\n\n'
          'Tap "Add Rule" to automatically allow Block Drop through the '
          'firewall (works for both Private and Public network profiles). '
          'Windows will ask for administrator permission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Process.run('control', ['firewall.cpl']);
            },
            child: const Text('Open Settings'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _addFirewallRule();
            },
            child: const Text('Add Rule'),
          ),
        ],
      ),
    );
  }

  Future<void> _addFirewallRule() async {
    final exe = Platform.resolvedExecutable.replaceAll('"', '');
    // Write a tiny .vbs file that uses ShellExecute with "runas" to
    // trigger UAC and run netsh with admin rights. This is the most
    // reliable elevation path on Windows without packaging changes.
    final vbs = File(
      '${Directory.systemTemp.path}\\blockdrop_fw.vbs',
    );
    await vbs.writeAsString(
      'Set sh = CreateObject("Shell.Application")\r\n'
      'sh.ShellExecute "netsh", '
      '"advfirewall firewall add rule '
      'name=""Block Drop"" dir=in action=allow '
      'program=""$exe"" profile=any", '
      '"", "runas", 1\r\n',
    );
    await Process.run('wscript', [vbs.path]);
    // Give the UAC-elevated process time to complete.
    await Future.delayed(const Duration(seconds: 4));
    await vbs.delete().catchError((_) => vbs);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Firewall rule added — try connecting again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _showInviteDialog(String fromName) {
    if (!mounted) return;
    final style = widget.settings.style;
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: styledDialogShape(style, cs),
        title: const Text('Game Invite'),
        content: Text('$fromName wants to play Block Drop with you!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _manager.rejectInvite();
            },
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _manager.acceptInvite();
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _buildBody(cs),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    switch (_manager.state) {
      case MultiplayerState.idle:
        return const Center(child: CircularProgressIndicator());

      case MultiplayerState.discovering:
        return _buildDiscovering(cs);

      case MultiplayerState.inviting:
        return _buildInviting(cs);

      case MultiplayerState.invited:
        // The dialog handles this state; show the peer list underneath
        return _buildDiscovering(cs);

      case MultiplayerState.inLobby:
        return _buildLobby(cs);

      case MultiplayerState.inGame:
      case MultiplayerState.gameOver:
        // Navigation to game screen is handled in _onManagerChanged
        return const Center(child: CircularProgressIndicator());
    }
  }

  // ── Discovering ───────────────────────────────────────────────────────────

  Widget _buildDiscovering(ColorScheme cs) {
    final localIp = _manager.localIp;
    final bcast = _manager.broadcastAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Searching on your network…',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // ── Diagnostic row ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: localIp == null
              ? Text(
                  '⚠ Could not detect LAN IP – make sure Wi-Fi is on.',
                  style: TextStyle(fontSize: 12, color: cs.error),
                )
              : Text(
                  'Your IP: $localIp  ·  broadcasting to: $bcast',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
        ),
        // ── Windows Firewall hint ─────────────────────────────────────────
        if (Platform.isWindows) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: _showFirewallDialog,
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 13, color: cs.tertiary),
                  const SizedBox(width: 5),
                  Text(
                    'Windows Firewall may block connections — tap to configure',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.tertiary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OTHER PLAYERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _manager.peers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No players found yet.\nMake sure others have Block Drop open on the same Wi-Fi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  itemCount: _manager.peers.length,
                  itemBuilder: (ctx, i) => _PeerTile(
                    peer: _manager.peers[i],
                    colorScheme: cs,
                    style: widget.settings.style,
                    onInvite: () => _manager.invitePeer(_manager.peers[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Inviting ──────────────────────────────────────────────────────────────

  Widget _buildInviting(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Waiting for ${_manager.opponentName ?? '…'} to respond…',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _manager.cancelInvite,
              style: OutlinedButton.styleFrom(
                shape: buttonBorderShape(widget.settings.style),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lobby ─────────────────────────────────────────────────────────────────

  Widget _buildLobby(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lobby',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _LobbyPlayerTile(
            name: _manager.playerName,
            label: 'You',
            isYou: true,
            colorScheme: cs,
            style: widget.settings.style,
          ),
          const SizedBox(height: 8),
          _LobbyPlayerTile(
            name: _manager.opponentName ?? '…',
            label: 'Opponent',
            isYou: false,
            colorScheme: cs,
            style: widget.settings.style,
          ),
          const Spacer(),
          if (_manager.isHost) ...[
            Text(
              'You are the host',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _manager.startGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Game'),
              style: FilledButton.styleFrom(
                shape: buttonBorderShape(widget.settings.style),
              ),
            ),
          ] else
            Text(
              'Waiting for host to start…',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _manager.backToDiscovery(),
            style: OutlinedButton.styleFrom(
              shape: buttonBorderShape(widget.settings.style),
            ),
            child: const Text('Leave Lobby'),
          ),
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _PeerTile extends StatelessWidget {
  final Peer peer;
  final ColorScheme colorScheme;
  final AppStyle style;
  final VoidCallback onInvite;

  const _PeerTile({
    required this.peer,
    required this.colorScheme,
    required this.style,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: panelDecoration(style, colorScheme),
      child: Row(
        children: [
          Icon(Icons.person, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  peer.ip,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onInvite,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
              shape: buttonBorderShape(style),
            ),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }
}

class _LobbyPlayerTile extends StatelessWidget {
  final String name;
  final String label;
  final bool isYou;
  final ColorScheme colorScheme;
  final AppStyle style;

  const _LobbyPlayerTile({
    required this.name,
    required this.label,
    required this.isYou,
    required this.colorScheme,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final radius = panelBorderRadius(style);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isYou
            ? colorScheme.primaryContainer.withAlpha(100)
            : colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: radius,
        border: Border.all(
          color: isYou
              ? colorScheme.primary.withAlpha(80)
              : colorScheme.outline.withAlpha(40),
          width: style == AppStyle.retro ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person,
            color: isYou ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isYou
                  ? colorScheme.primary.withAlpha(30)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: panelBorderRadius(style),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color:
                    isYou ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
