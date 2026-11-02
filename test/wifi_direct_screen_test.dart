import 'dart:async';

import 'package:block_drop/multiplayer/multiplayer_manager.dart';
import 'package:block_drop/multiplayer/direct_join_invite.dart';
import 'package:block_drop/multiplayer/wifi_direct.dart';
import 'package:block_drop/screens/multiplayer_wifi_direct_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SimulatedWifiDirect implements WifiDirectPlatform {
  final updates = StreamController<WifiDirectSnapshot>.broadcast(sync: true);
  WifiDirectSnapshot current = const WifiDirectSnapshot(
    supported: true,
    wifiEnabled: true,
    permissionGranted: true,
    peers: [
      WifiDirectPeer(name: 'Test host', address: 'aa:bb:cc:dd:ee:ff', status: 3)
    ],
  );

  @override
  Stream<WifiDirectSnapshot> get events => updates.stream;

  @override
  Future<WifiDirectSnapshot> status() async => current;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> discover() async {}

  @override
  Future<List<WifiDirectPeer>> peers() async => current.peers;

  @override
  Future<void> createGroup() async {}

  @override
  Future<void> connect(String address) async {
    current = const WifiDirectSnapshot(
      supported: true,
      wifiEnabled: true,
      permissionGranted: true,
      connected: true,
      groupOwner: false,
      groupOwnerIp: '127.0.0.1',
    );
    updates.add(current);
  }

  @override
  Future<void> cancelConnect() async {}

  @override
  Future<void> disconnect() async {}
}

class RecordingJoinManager extends MultiplayerManager {
  DirectJoinInvite? lastInvitation;

  RecordingJoinManager() : super(playerName: 'Guest');

  @override
  Future<void> joinHost(DirectJoinInvite invite, {String? hostName}) async {
    lastInvitation = invite;
    state = MultiplayerState.inviting;
    notifyListeners();
  }
}

void main() {
  testWidgets('simulated P2P owner IP is used by the TCP join adapter',
      (tester) async {
    final guest = RecordingJoinManager();
    final native = SimulatedWifiDirect();
    final wifi = WifiDirectController(platform: native);
    addTearDown(guest.dispose);
    addTearDown(wifi.dispose);
    addTearDown(native.updates.close);
    final invitation = DirectJoinInvite(
      host: '192.168.1.20',
      port: 45679,
      token: DirectJoinInvite.generateToken(),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => FilledButton(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => MultiplayerWifiDirectScreen(
                        manager: guest,
                        controller: wifi,
                      ),
                    )),
                    child: const Text('Open Wi-Fi Direct'),
                  ))),
    ));
    await tester.tap(find.text('Open Wi-Fi Direct'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Test host'));
    await tester.tap(find.text('Test host'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('wifi-direct-join-code')));
    await tester.enterText(
      find.byKey(const Key('wifi-direct-join-code')),
      invitation.toUri().toString(),
    );
    await tester.ensureVisible(find.byKey(const Key('wifi-direct-join')));
    await tester.tap(find.byKey(const Key('wifi-direct-join')));
    await tester.pumpAndSettle();
    expect(guest.lastInvitation?.host, '127.0.0.1');
    expect(guest.lastInvitation?.port, invitation.port);
    expect(guest.lastInvitation?.token, invitation.token);
    expect(guest.state, MultiplayerState.inviting);
    await tester.pumpWidget(const SizedBox());
  });
}
