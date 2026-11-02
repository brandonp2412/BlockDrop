import 'dart:convert';
import 'dart:io';

import 'package:block_drop/game/gameplay_settings.dart';
import 'package:block_drop/multiplayer/multiplayer_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discovery notifies after asynchronous network setup', () async {
    final manager = MultiplayerManager(playerName: 'Listener test');
    final observedStates = <MultiplayerState>[];
    manager.addListener(() => observedStates.add(manager.state));

    await manager.startDiscovery();

    expect(manager.state, MultiplayerState.discovering);
    expect(manager.nearbyStatus, NearbyDiscoveryStatus.searching);
    expect(observedStates, everyElement(MultiplayerState.discovering));
    expect(observedStates.length, greaterThanOrEqualTo(2));
    manager.dispose();
  });

  test('real UDP announcement still supplies a working nearby TCP invite',
      () async {
    final host = MultiplayerManager(playerName: 'Host');
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    await host.startHosting(port: 0);
    await guest.startDiscovery();
    expect(guest.nearbyStatus, NearbyDiscoveryStatus.searching);

    final sender =
        await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(sender.close);
    final payload = utf8.encode(jsonEncode({
      'type': 'announce',
      'id': host.playerId,
      'name': host.playerName,
      'port': host.hostingPort,
      'token': host.pairingToken,
      'status': 'discovering',
    }));
    sender.send(payload, InternetAddress.loopbackIPv4, 45678);
    for (var i = 0; i < 100 && guest.peers.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(guest.peers, hasLength(1));
    expect(guest.peers.single.ip, '127.0.0.1');
    expect(guest.peers.single.port, host.hostingPort);
    sender.send(payload, InternetAddress.loopbackIPv4, 45678);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(guest.peers, hasLength(1));

    await guest.invitePeer(guest.peers.single);
    for (var i = 0; i < 100 && host.state != MultiplayerState.invited; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(host.state, MultiplayerState.invited);
    host.acceptInvite();
    for (var i = 0; i < 100 && guest.state != MultiplayerState.inLobby; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(guest.state, MultiplayerState.inLobby);
    expect(host.isHost, isTrue);
    expect(guest.isHost, isFalse);
  });

  test('UDP bind retry does not restart TCP hosting or change pairing token',
      () async {
    var bindAttempts = 0;
    final manager = MultiplayerManager(
      playerName: 'Retrying host',
      bindDiscoverySocket: (address, port) async {
        bindAttempts++;
        if (bindAttempts == 1) {
          throw const SocketException('UDP unavailable');
        }
        return RawDatagramSocket.bind(address, port, reuseAddress: true);
      },
    );
    addTearDown(manager.dispose);

    await manager.startDiscovery();
    expect(manager.nearbyStatus, NearbyDiscoveryStatus.unavailable);
    final port = manager.hostingPort;
    final token = manager.pairingToken;
    expect(port, greaterThan(0));

    await manager.startDiscovery();
    expect(bindAttempts, 2);
    expect(manager.nearbyStatus, NearbyDiscoveryStatus.searching);
    expect(manager.nearbyFailure, isNull);
    expect(manager.hostingPort, port);
    expect(manager.pairingToken, token);
  });

  test('returning to discovery restores this device gameplay rules', () {
    const localRules = GameplaySettings(
      initialDropSpeed: 1400,
      speedIncrement: 25,
      maximumLevel: 12,
      linesPerLevel: 7,
      softDropEnabled: false,
      holdEnabled: false,
    );
    const remoteRules = GameplaySettings(
      initialDropSpeed: 300,
      speedIncrement: 150,
      maximumLevel: 3,
      linesPerLevel: 2,
      softDropEnabled: true,
      holdEnabled: true,
    );

    final manager = MultiplayerManager(
      playerName: 'Local player',
      gameplaySettings: localRules,
    );

    manager.gameplaySettings = remoteRules;
    manager.enableHold = remoteRules.holdEnabled;
    manager.state = MultiplayerState.inGame;

    manager.backToDiscovery();

    expect(manager.state, MultiplayerState.discovering);
    expect(manager.gameplaySettings.toMap(), localRules.toMap());
    expect(manager.enableHold, isFalse);

    manager.dispose();
  });
}
