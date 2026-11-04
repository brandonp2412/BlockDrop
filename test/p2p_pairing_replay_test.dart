import 'dart:async';
import 'dart:io';

import 'package:block_drop/multiplayer/direct_join_invite.dart';
import 'package:block_drop/multiplayer/multiplayer_game_config.dart';
import 'package:block_drop/multiplayer/multiplayer_manager.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitForPairingState(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
          'Pairing state did not arrive within four seconds');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test('retired pairing code cannot be replayed after a finished match',
      () async {
    await HttpOverrides.runZoned<Future<void>>(() async {
      final host = MultiplayerManager(playerName: 'Host');
      final guest = MultiplayerManager(playerName: 'Guest');
      addTearDown(host.dispose);
      addTearDown(guest.dispose);
      final errors = <String>[];
      guest.onError = errors.add;

      await host.startHosting(port: 0);
      final staleCode = host.hostingInvite('127.0.0.1').toUri().toString();
      await guest.joinHost(DirectJoinInvite.fromUri(staleCode));
      await waitForPairingState(() => host.state == MultiplayerState.invited);
      host.acceptInvite();
      await waitForPairingState(() => guest.state == MultiplayerState.inLobby);

      guest.setGameMode(MultiplayerGameMode.sharedPieces);
      guest.startGame();
      expect(guest.state, MultiplayerState.inLobby);
      expect(host.gameMode, MultiplayerGameMode.independent);
      host.startGame();
      await waitForPairingState(() => guest.state == MultiplayerState.inGame);
      expect(guest.gameConfig.mode, MultiplayerGameMode.independent);

      final hostBoard = List<int>.filled(200, 0)..[1] = 2;
      final guestBoard = List<int>.filled(200, 0)..[198] = 5;
      host.sendBoardSnapshot(hostBoard, 120, 3);
      guest.sendBoardSnapshot(guestBoard, 450, 6);
      await waitForPairingState(
        () => host.opponentScore == 450 && guest.opponentScore == 120,
      );
      expect(host.opponentBoard, guestBoard);
      expect(guest.opponentBoard, hostBoard);
      host.sendGameOver(120);
      guest.sendGameOver(450);
      await waitForPairingState(
        () => host.opponentIsGameOver && guest.opponentIsGameOver,
      );
      expect(host.state, MultiplayerState.gameOver);
      expect(guest.state, MultiplayerState.gameOver);

      guest.backToDiscovery();
      host.backToDiscovery();
      final freshCode = host.hostingInvite('127.0.0.1').toUri().toString();
      expect(freshCode, isNot(staleCode));
      expect(host.nearbyStatus, NearbyDiscoveryStatus.off);

      await guest.joinHost(DirectJoinInvite.fromUri(staleCode));
      await waitForPairingState(
          () => guest.state == MultiplayerState.discovering);
      expect(errors.last, contains('Join rejected'));
      expect(host.state, MultiplayerState.discovering);
      expect(host.hostingInvite('127.0.0.1').toUri().toString(), freshCode);

      await guest.joinHost(DirectJoinInvite.fromUri(freshCode));
      await waitForPairingState(() => host.state == MultiplayerState.invited);
      host.acceptInvite();
      await waitForPairingState(() => guest.state == MultiplayerState.inLobby);
      expect(guest.isHost, isFalse);
      expect(host.isHost, isTrue);
    }, createHttpClient: (_) {
      throw StateError('Direct LAN pairing must not use HTTP');
    });
  });
}
