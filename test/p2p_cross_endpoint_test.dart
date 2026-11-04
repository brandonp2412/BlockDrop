import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:block_drop/multiplayer/direct_join_invite.dart';
import 'package:block_drop/multiplayer/multiplayer_manager.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitForCrossEndpoint(
  bool Function() condition,
  String description, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Timed out waiting for $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  final role = Platform.environment['BLOCKDROP_P2P_ROLE'];
  test(
    'actual managers finish an authenticated cross-process TCP match',
    () async {
      await HttpOverrides.runZoned<Future<void>>(() async {
        final manager = MultiplayerManager(playerName: 'Cross-process $role');
        addTearDown(manager.dispose);
        final inviteFile = Platform.environment['BLOCKDROP_P2P_INVITE_FILE'];

        if (role == 'host') {
          final hostAddress = Platform.environment['BLOCKDROP_P2P_ADDRESS'];
          if (hostAddress == null || hostAddress.isEmpty) {
            throw ArgumentError('BLOCKDROP_P2P_ADDRESS is required for host');
          }
          final privateDirectory =
              await Directory.systemTemp.createTemp('blockdrop-p2p11-');
          addTearDown(() => privateDirectory.delete(recursive: true));
          await manager.startHosting(port: 0);
          final invite = manager.hostingInvite(hostAddress);
          final file = File('${privateDirectory.path}/invite.txt');
          await file.writeAsString(invite.toUri().toString(), flush: true);
          print(
            'BLOCKDROP_P2P_READY inviteFile=${file.path} '
            'host=${invite.host} port=${invite.port}',
          );
          await waitForCrossEndpoint(
            () => manager.state == MultiplayerState.invited,
            'authenticated guest join',
          );
          manager.acceptInvite();
          manager.startGame();
        } else if (role == 'guest') {
          if (inviteFile == null || inviteFile.isEmpty) {
            throw ArgumentError(
                'BLOCKDROP_P2P_INVITE_FILE is required for guest');
          }
          final invite = DirectJoinInvite.fromUri(
            (await File(inviteFile).readAsString()).trim(),
          );
          await manager.joinHost(invite);
          await waitForCrossEndpoint(
            () => manager.state == MultiplayerState.inGame,
            'host start',
          );
        } else {
          throw ArgumentError('Role must be host or guest');
        }

        final isHost = role == 'host';
        final localBoard = List<int>.filled(200, 0)
          ..[isHost ? 0 : 199] = isHost ? 2 : 5;
        final remoteBoard = List<int>.filled(200, 0)
          ..[isHost ? 199 : 0] = isHost ? 5 : 2;
        final localScore = isHost ? 123 : 456;
        final remoteScore = isHost ? 456 : 123;
        final localLines = isHost ? 4 : 7;
        final remoteLines = isHost ? 7 : 4;

        manager.sendBoardSnapshot(localBoard, localScore, localLines);
        await waitForCrossEndpoint(
          () =>
              manager.opponentScore == remoteScore &&
              manager.opponentLines == remoteLines,
          'remote board, score, and lines',
          timeout: const Duration(seconds: 15),
        );
        expect(manager.opponentBoard, remoteBoard);
        expect(manager.nearbyStatus, NearbyDiscoveryStatus.off);
        expect(manager.isHost, isHost);

        manager.sendGameOver(localScore);
        await waitForCrossEndpoint(
          () => manager.opponentIsGameOver,
          'remote game-over',
          timeout: const Duration(seconds: 15),
        );
        expect(manager.state, MultiplayerState.gameOver);
        expect(manager.opponentScore, remoteScore);

        print('BLOCKDROP_P2P_PROOF ${jsonEncode({
              'role': role,
              'atUtc': DateTime.now().toUtc().toIso8601String(),
              'localScore': localScore,
              'localLines': localLines,
              'opponentScore': manager.opponentScore,
              'opponentLines': manager.opponentLines,
              'opponentCellIndex': isHost ? 199 : 0,
              'opponentCellValue': manager.opponentBoard[isHost ? 199 : 0],
              'state': manager.state.name,
              'opponentIsGameOver': manager.opponentIsGameOver,
              'udp': manager.nearbyStatus.name,
            })}');
      }, createHttpClient: (_) {
        throw StateError('LAN pairing must not create an HTTP client');
      });
    },
    skip: role == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
