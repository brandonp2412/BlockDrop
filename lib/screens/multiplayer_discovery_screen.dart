import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../multiplayer/multiplayer_game_config.dart';
import '../multiplayer/multiplayer_manager.dart';
import '../widgets/empty_state.dart';
import '../multiplayer/peer.dart';
import '../settings/settings_provider.dart';
import '../widgets/game_decorations.dart';
import 'multiplayer_game_screen.dart';
import 'multiplayer_host_screen.dart';
import 'multiplayer_join_screen.dart';

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

  bool _managerInitialized = false;
  String? _tcpStartupError;

  Future<void> _startTcpHost() async {
    try {
      await _manager.startHosting();
      if (mounted) setState(() => _tcpStartupError = null);
    } catch (error) {
      if (mounted) {
        setState(
            () => _tcpStartupError = 'Cannot listen for TCP guests: $error');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_managerInitialized) return;

    final l10n = context.l10n;
    _manager = MultiplayerManager(
      playerName: _defaultPlayerName(l10n),
      gameplaySettings: widget.settings.gameplay,
      unknownPlayerName: l10n.text('Unknown'),
      opponentFallbackName: l10n.text('Opponent'),
    );
    _manager.onError = _showError;
    _manager.onInviteReceived = _showInviteDialog;
    _manager.addListener(_onManagerChanged);
    _managerInitialized = true;
    unawaited(_startTcpHost());
  }

  String _defaultPlayerName(AppLocalizations l10n) {
    try {
      final h = Platform.localHostname.split('.').first;
      if (h.isEmpty || h.toLowerCase() == 'localhost') {
        return l10n.text('Player');
      }
      return h;
    } catch (_) {
      return l10n.text('Player');
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
        title: Text(context.l10n.text('Windows Firewall')),
        content: Text(
          context.l10n.text(
            'Windows Firewall may be blocking other players from connecting to '
            'this device.\n\n'
            'Tap "Add Rule" to automatically allow Block Drop through the '
            'firewall (works for both Private and Public network profiles). '
            'Windows will ask for administrator permission.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.text('Dismiss')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Process.run('control', ['firewall.cpl']);
            },
            child: Text(context.l10n.text('Open Settings')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _addFirewallRule();
            },
            child: Text(context.l10n.text('Add Rule')),
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
    final vbs = File('${Directory.systemTemp.path}\\blockdrop_fw.vbs');
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
      SnackBar(
        content: Text(
          context.l10n.text('Firewall rule added — try connecting again.'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.runtimeText(msg)),
        behavior: SnackBarBehavior.floating,
      ),
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
        title: Text(context.l10n.text('Game Invite')),
        content: Text(
          context.l10n.text(
            '{name} wants to play Block Drop with you!',
            {'name': fromName},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _manager.rejectInvite();
            },
            child: Text(context.l10n.text('Decline')),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _manager.acceptInvite();
            },
            child: Text(context.l10n.text('Accept')),
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
        title: Text(context.l10n.text('Multiplayer')),
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody(cs)),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    switch (_manager.state) {
      case MultiplayerState.idle:
        if (_tcpStartupError == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_tcpStartupError!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => unawaited(_startTcpHost()),
                  child: const Text('Retry TCP listener'),
                ),
              ],
            ),
          ),
        );

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

  Widget _buildDiscovering(ColorScheme cs) {
    final localIp = _manager.localIp;
    final bcast = _manager.broadcastAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            key: const Key('host-game-button'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MultiplayerHostScreen(manager: _manager),
              ),
            ),
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Host game · QR & join code'),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            key: const Key('join-game-button'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MultiplayerJoinScreen(manager: _manager),
              ),
            ),
            icon: const Icon(Icons.link_rounded),
            label: const Text('Join game · scan QR or enter IP'),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            key: const Key('find-nearby-button'),
            onPressed: _manager.nearbyStatus == NearbyDiscoveryStatus.searching
                ? null
                : () => unawaited(_manager.startDiscovery()),
            icon: const Icon(Icons.wifi_find_rounded),
            label: Text(
              _manager.nearbyStatus == NearbyDiscoveryStatus.unavailable
                  ? 'Retry Find Nearby'
                  : 'Find Nearby · optional LAN discovery',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            switch (_manager.nearbyStatus) {
              NearbyDiscoveryStatus.off =>
                'Nearby search is off. QR and manual IP work without UDP.',
              NearbyDiscoveryStatus.searching =>
                'Searching on your LAN using UDP 45678…',
              NearbyDiscoveryStatus.unavailable =>
                _manager.nearbyFailure ?? 'UDP discovery unavailable.',
            },
            key: const Key('nearby-status'),
            style: TextStyle(
              color: _manager.nearbyStatus == NearbyDiscoveryStatus.unavailable
                  ? cs.error
                  : cs.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        if (_manager.nearbyStatus == NearbyDiscoveryStatus.searching) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: localIp == null
                ? Text(
                    context.l10n.text(
                      '⚠ Could not detect LAN IP – make sure Wi-Fi is on.',
                    ),
                    style: TextStyle(fontSize: 12, color: cs.error),
                  )
                : Text(
                    context.l10n.text(
                      'Your IP: {ip}  ·  broadcasting to: {broadcast}',
                      {'ip': localIp, 'broadcast': bcast},
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        ],
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
                    context.l10n.text(
                      'Windows Firewall may block connections — tap to configure',
                    ),
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
            context.l10n.text('OTHER PLAYERS'),
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
              ? AppEmptyState(
                  icon: Icons.wifi_find_rounded,
                  title: _manager.nearbyStatus == NearbyDiscoveryStatus.off
                      ? 'Nearby search off'
                      : 'No players found yet',
                  message: _manager.nearbyStatus == NearbyDiscoveryStatus.off
                      ? 'Tap Find Nearby to discover LAN hosts, or join directly by QR or IP.'
                      : 'Nearby hosts appear here if UDP broadcasts can reach this device.',
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
              context.l10n.text(
                'Waiting for {name} to respond…',
                {'name': _manager.opponentName ?? '…'},
              ),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _manager.cancelInvite,
              style: OutlinedButton.styleFrom(
                shape: buttonBorderShape(widget.settings.style),
              ),
              child: Text(context.l10n.text('Cancel')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobby(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.text('Lobby'),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _LobbyPlayerTile(
            name: _manager.playerName,
            label: context.l10n.text('You'),
            isYou: true,
            colorScheme: cs,
            style: widget.settings.style,
          ),
          const SizedBox(height: 8),
          _LobbyPlayerTile(
            name: _manager.opponentName ?? '…',
            label: context.l10n.text('Opponent'),
            isYou: false,
            colorScheme: cs,
            style: widget.settings.style,
          ),
          const SizedBox(height: 18),
          if (_manager.isHost) ...[
            _LobbyModeSelector(
              mode: _manager.gameMode,
              colorScheme: cs,
              onChanged: _manager.setGameMode,
            ),
            const SizedBox(height: 16),
            _LobbyHoldSelector(
              enabled: _manager.enableHold,
              colorScheme: cs,
              style: widget.settings.style,
              onChanged: (value) => setState(() => _manager.enableHold = value),
            ),
          ] else
            _LobbyModeStatus(mode: _manager.gameMode, colorScheme: cs),
          const Spacer(),
          if (_manager.isHost) ...[
            Text(
              context.l10n.text('You are the host'),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _manager.startGame,
              icon: const Icon(Icons.play_arrow),
              label: Text(context.l10n.text('Start Game')),
              style: FilledButton.styleFrom(
                shape: buttonBorderShape(widget.settings.style),
              ),
            ),
          ] else
            Text(
              context.l10n.text('Waiting for host to start…'),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _manager.backToDiscovery(),
            style: OutlinedButton.styleFrom(
              shape: buttonBorderShape(widget.settings.style),
            ),
            child: Text(context.l10n.text('Leave Lobby')),
          ),
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

IconData _gameModeIcon(MultiplayerGameMode mode) {
  return switch (mode) {
    MultiplayerGameMode.independent => Icons.shuffle,
    MultiplayerGameMode.sharedPieces => Icons.sync,
  };
}

class _LobbyModeSelector extends StatelessWidget {
  final MultiplayerGameMode mode;
  final ColorScheme colorScheme;
  final ValueChanged<MultiplayerGameMode> onChanged;

  const _LobbyModeSelector({
    required this.mode,
    required this.colorScheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          context.l10n.text('Mode'),
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 8),
        SegmentedButton<MultiplayerGameMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: MultiplayerGameMode.independent,
              icon: const Icon(Icons.shuffle),
              label: Text(context.l10n.text('Random')),
            ),
            ButtonSegment(
              value: MultiplayerGameMode.sharedPieces,
              icon: const Icon(Icons.sync),
              label: Text(context.l10n.text('Fair')),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) onChanged(selection.first);
          },
        ),
      ],
    );
  }
}

class _LobbyModeStatus extends StatelessWidget {
  final MultiplayerGameMode mode;
  final ColorScheme colorScheme;

  const _LobbyModeStatus({required this.mode, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(_gameModeIcon(mode), size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          context.l10n.text(
            '{mode} mode',
            {'mode': context.l10n.text(mode.label)},
          ),
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _LobbyHoldSelector extends StatelessWidget {
  final bool enabled;
  final ColorScheme colorScheme;
  final AppStyle style;
  final ValueChanged<bool> onChanged;

  const _LobbyHoldSelector({
    required this.enabled,
    required this.colorScheme,
    required this.style,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.l10n.text('Hold Piece'),
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(width: 12),
        Switch(value: enabled, onChanged: onChanged),
      ],
    );
  }
}

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
            child: Text(context.l10n.text('Invite')),
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
              context.l10n.text(label),
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
