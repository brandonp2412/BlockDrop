import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:block_drop/game/gameplay_settings.dart';
import 'package:block_drop/multiplayer/direct_join_invite.dart';
import 'package:block_drop/multiplayer/multiplayer_game_config.dart';
import 'package:block_drop/multiplayer/multiplayer_manager.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within four seconds');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<Map<String, dynamic>> rawJoin(int port, String payload) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  try {
    socket.write(payload);
    await socket.flush();
    final line = await socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 3));
    return jsonDecode(line) as Map<String, dynamic>;
  } finally {
    socket.destroy();
  }
}

void main() {
  test('versioned URI and crypto token validation', () {
    const invite = DirectJoinInvite(
      host: '192.168.1.42',
      port: 45679,
      token: 'abcdef0123456789abcdef0123456789abcdef0123456789',
    );
    expect(DirectJoinInvite.fromUri(invite.toUri().toString()).toUri(),
        invite.toUri());
    final token = DirectJoinInvite.generateToken();
    expect(token, matches(RegExp(r'^[0-9a-f]{48}$')));
    expect(DirectJoinInvite.generateToken(), isNot(token));
    expect(
        () => DirectJoinInvite.fromUri(
              invite.toUri().toString().replaceFirst('v=1', 'v=2'),
            ),
        throwsFormatException);
    expect(
        () => DirectJoinInvite.fromUri(
              '${invite.toUri()}&port=9999',
            ),
        throwsFormatException);
  });

  test(
      'direct TCP host works without UDP; bidirectional boards and finish; reconnect',
      () async {
    const hostRules = GameplaySettings(
      initialDropSpeed: 750,
      speedIncrement: 100,
      maximumLevel: 5,
      linesPerLevel: 4,
      softDropEnabled: true,
      holdEnabled: false,
    );
    final host =
        MultiplayerManager(playerName: 'Host', gameplaySettings: hostRules);
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    await host.startHosting(port: 0);
    expect(host.hostingPort, greaterThan(0));
    expect(host.isHost, isTrue);
    expect(host.broadcastAddress, isNull);
    final invite = host.hostingInvite('127.0.0.1');
    final token = invite.token;

    await guest.joinHost(invite);
    await waitUntil(() => host.state == MultiplayerState.invited);
    expect(guest.state, MultiplayerState.inviting);
    expect(guest.isHost, isFalse);
    host.acceptInvite();
    await waitUntil(() => guest.state == MultiplayerState.inLobby);
    expect(host.isHost, isTrue);
    host.setGameMode(MultiplayerGameMode.sharedPieces);
    host.enableHold = false;
    host.startGame();
    await waitUntil(() => guest.state == MultiplayerState.inGame);
    expect(guest.gameConfig.mode, MultiplayerGameMode.sharedPieces);
    expect(guest.gameConfig.pieceSeed, host.gameConfig.pieceSeed);
    expect(guest.gameConfig.gameplaySettings.toMap(), hostRules.toMap());

    final hostBoard = List<int>.filled(200, 0)..[0] = 3;
    final guestBoard = List<int>.filled(200, 0)..[199] = 4;
    host.sendBoardSnapshot(hostBoard, 123, 2);
    guest.sendBoardSnapshot(guestBoard, 456, 7);
    await waitUntil(
        () => host.opponentScore == 456 && guest.opponentScore == 123);
    expect(host.opponentBoard, guestBoard);
    expect(guest.opponentBoard, hostBoard);
    expect(host.opponentLines, 7);
    expect(guest.opponentLines, 2);

    host.sendGameOver(123);
    guest.sendGameOver(456);
    await waitUntil(() => host.opponentIsGameOver && guest.opponentIsGameOver);
    expect(host.state, MultiplayerState.gameOver);
    expect(guest.state, MultiplayerState.gameOver);
    host.backToDiscovery();
    await waitUntil(() => guest.state == MultiplayerState.discovering);
    expect(host.pairingToken, isNot(token));
    expect(host.hostingPort, invite.port);
    expect(guest.opponentBoard, everyElement(0));

    await guest.joinHost(host.hostingInvite('127.0.0.1'));
    await waitUntil(() => host.state == MultiplayerState.invited);
    host.acceptInvite();
    await waitUntil(() => guest.state == MultiplayerState.inLobby);
    expect(host.isHost, isTrue);
    expect(guest.isHost, isFalse);
  });

  test('invalid, expired and wrong-version join are rejected; host recovers',
      () async {
    var now = DateTime.utc(2026, 11, 3);
    final host = MultiplayerManager(playerName: 'Host', now: () => now);
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    await host.startHosting(port: 0, tokenLifetime: const Duration(minutes: 1));
    final invite = host.hostingInvite('127.0.0.1');
    final errors = <String>[];
    guest.onError = errors.add;

    await guest.joinHost(DirectJoinInvite(
      host: invite.host,
      port: invite.port,
      token: DirectJoinInvite.generateToken(),
    ));
    await waitUntil(() => guest.state == MultiplayerState.discovering);
    expect(errors.single, contains('Join rejected'));
    expect(host.state, MultiplayerState.discovering);
    final response = await rawJoin(
        invite.port,
        '${jsonEncode({
              'type': 'join',
              'version': 2,
              'token': invite.token,
              'id': 'bad-version',
              'name': 'Bad version',
            })}\n');
    expect(response['type'], 'join_reject');

    now = now.add(const Duration(minutes: 2));
    await guest.joinHost(invite);
    await waitUntil(() => guest.state == MultiplayerState.discovering);
    expect(host.state, MultiplayerState.discovering);
    host.refreshPairingToken();
    await guest.joinHost(host.hostingInvite('127.0.0.1'));
    await waitUntil(() => host.state == MultiplayerState.invited);
    host.rejectInvite();
    await waitUntil(() => guest.state == MultiplayerState.discovering);
    expect(errors.last, contains('declined'));
    expect(host.state, MultiplayerState.discovering);
  });

  test('malformed, missing-auth and oversized frames do not consume listener',
      () async {
    final host = MultiplayerManager(playerName: 'Host');
    addTearDown(host.dispose);
    await host.startHosting(port: 0);
    final port = host.hostingPort!;
    for (final payload in [
      'not json\n',
      '${List.filled(16 * 1024 + 1, 'x').join()}\n',
      '{"type":"invite"}\n',
    ]) {
      final response = await rawJoin(port, payload);
      expect(response['type'], 'join_reject');
      await waitUntil(() => host.state == MultiplayerState.discovering);
    }
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(guest.dispose);
    await guest.joinHost(host.hostingInvite('127.0.0.1'));
    await waitUntil(() => host.state == MultiplayerState.invited);
    host.acceptInvite();
    await waitUntil(() => guest.state == MultiplayerState.inLobby);
  });

  test('double join is refused without affecting the active guest', () async {
    final host = MultiplayerManager(playerName: 'Host');
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    await host.startHosting(port: 0);
    final invite = host.hostingInvite('127.0.0.1');
    await guest.joinHost(invite);
    await waitUntil(() => host.state == MultiplayerState.invited);
    host.acceptInvite();
    await waitUntil(() => guest.state == MultiplayerState.inLobby);
    final response = await rawJoin(
        invite.port,
        '${jsonEncode({
              'type': 'join',
              'version': DirectJoinInvite.protocolVersion,
              'token': invite.token,
              'id': 'extra',
              'name': 'Extra',
            })}\n');
    expect(response['reason'], 'busy');
    expect(host.state, MultiplayerState.inLobby);
    expect(guest.state, MultiplayerState.inLobby);
  });

  test('abandoned, malformed gameplay and cancelled joins reset the host',
      () async {
    final host = MultiplayerManager(playerName: 'Host');
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(host.dispose);
    await host.startHosting(port: 0);
    var invite = host.hostingInvite('127.0.0.1');
    await guest.joinHost(invite);
    await waitUntil(() => host.state == MultiplayerState.invited);
    guest.cancelInvite();
    await waitUntil(() => host.state == MultiplayerState.discovering);
    expect(host.pairingToken, isNot(invite.token));

    invite = host.hostingInvite('127.0.0.1');
    final socket = await Socket.connect('127.0.0.1', invite.port);
    addTearDown(socket.destroy);
    socket.write('${jsonEncode({
          'type': 'join',
          'version': 1,
          'token': invite.token,
          'id': 'hostile',
          'name': 'Untrusted guest',
        })}\n');
    await socket.flush();
    await waitUntil(() => host.state == MultiplayerState.invited);
    socket.write('${jsonEncode({
          'type': 'game_start',
          'mode': 'shared_pieces',
        })}\n');
    await socket.flush();
    await waitUntil(() => host.state == MultiplayerState.discovering);
    expect(host.pairingToken, isNot(invite.token));

    await guest.joinHost(host.hostingInvite('127.0.0.1'));
    await waitUntil(() => host.state == MultiplayerState.invited);
    host.acceptInvite();
    await waitUntil(() => guest.state == MultiplayerState.inLobby);
    guest.dispose();
    await waitUntil(() => host.state == MultiplayerState.discovering);
  });

  test('silent unauthenticated socket times out without consuming host',
      () async {
    final host = MultiplayerManager(
      playerName: 'Host',
      handshakeTimeout: const Duration(milliseconds: 250),
    );
    addTearDown(host.dispose);
    await host.startHosting(port: 0);
    final socket = await Socket.connect('127.0.0.1', host.hostingPort!);
    addTearDown(socket.destroy);
    final response = await socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 3));
    expect((jsonDecode(response) as Map<String, dynamic>)['reason'], 'timeout');
    expect(host.state, MultiplayerState.discovering);

    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(guest.dispose);
    await guest.joinHost(host.hostingInvite('127.0.0.1'));
    await waitUntil(() => host.state == MultiplayerState.invited);
  });

  test('blocked UDP discovery reports failure while QR TCP game completes',
      () async {
    final host = MultiplayerManager(
      playerName: 'Host',
      bindDiscoverySocket: (_, __) async =>
          throw const SocketException('UDP bind blocked in test'),
    );
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(host.dispose);
    addTearDown(guest.dispose);

    final errors = <String>[];
    host.onError = errors.add;
    await host.startDiscovery();
    expect(host.nearbyStatus, NearbyDiscoveryStatus.unavailable);
    expect(host.nearbyFailure, contains('UDP bind blocked in test'));
    expect(errors.single, contains('UDP port 45678'));
    expect(host.hostingPort, greaterThan(0));
    expect(host.pairingToken, isNotNull);

    await guest.joinHost(host.hostingInvite('127.0.0.1'));
    await waitUntil(() => host.state == MultiplayerState.invited);
    host.acceptInvite();
    await waitUntil(() => guest.state == MultiplayerState.inLobby);
    host.startGame();
    await waitUntil(() => guest.state == MultiplayerState.inGame);

    final hostBoard = List<int>.filled(200, 0)..[7] = 2;
    final guestBoard = List<int>.filled(200, 0)..[105] = 6;
    host.sendBoardSnapshot(hostBoard, 90, 3);
    guest.sendBoardSnapshot(guestBoard, 220, 8);
    await waitUntil(
        () => host.opponentScore == 220 && guest.opponentScore == 90);
    expect(host.opponentBoard, guestBoard);
    expect(guest.opponentBoard, hostBoard);
    expect(host.opponentLines, 8);
    expect(guest.opponentLines, 3);

    host.sendGameOver(90);
    guest.sendGameOver(220);
    await waitUntil(() => host.opponentIsGameOver && guest.opponentIsGameOver);
    expect(host.state, MultiplayerState.gameOver);
    expect(guest.state, MultiplayerState.gameOver);
    expect(host.hostingPort, greaterThan(0));
  });

  test('occupied preferred port falls back to a free port', () async {
    final occupied = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    addTearDown(occupied.close);
    final host = MultiplayerManager(playerName: 'Host');
    addTearDown(host.dispose);
    await host.startHosting(port: occupied.port);
    expect(host.hostingPort, isNot(occupied.port));
    expect(host.hostingPort, greaterThan(0));
  });
}
