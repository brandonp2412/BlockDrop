import 'dart:async';

import 'package:block_drop/multiplayer/wifi_direct.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWifiDirectPlatform implements WifiDirectPlatform {
  final controller = StreamController<WifiDirectSnapshot>.broadcast(sync: true);
  WifiDirectSnapshot current = const WifiDirectSnapshot(
    supported: true,
    wifiEnabled: true,
    permissionGranted: true,
  );
  bool permissionAllowed = true;
  bool formGroup = true;
  bool wrongRole = false;
  int cancels = 0;
  int disconnects = 0;

  void publish(WifiDirectSnapshot next) {
    current = next;
    controller.add(next);
  }

  @override
  Stream<WifiDirectSnapshot> get events => controller.stream;

  @override
  Future<WifiDirectSnapshot> status() async => current;

  @override
  Future<bool> requestPermission() async => permissionAllowed;

  @override
  Future<void> discover() async {}

  @override
  Future<List<WifiDirectPeer>> peers() async => current.peers;

  @override
  Future<void> createGroup() async {
    if (formGroup)
      publish(WifiDirectSnapshot(
        supported: true,
        wifiEnabled: true,
        permissionGranted: true,
        connected: true,
        groupOwner: !wrongRole,
        groupOwnerIp: '192.168.49.1',
      ));
  }

  @override
  Future<void> connect(String address) async {
    if (formGroup)
      publish(WifiDirectSnapshot(
        supported: true,
        wifiEnabled: true,
        permissionGranted: true,
        connected: true,
        groupOwner: wrongRole,
        groupOwnerIp: '192.168.49.1',
      ));
  }

  @override
  Future<void> cancelConnect() async => cancels++;

  @override
  Future<void> disconnect() async {
    disconnects++;
    publish(const WifiDirectSnapshot(
      supported: true,
      wifiEnabled: true,
      permissionGranted: true,
    ));
  }

  Future<void> close() async => controller.close();
}

void main() {
  test('host waits for Android owner address and preserves TCP separation',
      () async {
    final fake = FakeWifiDirectPlatform();
    final wifi = WifiDirectController(platform: fake);
    addTearDown(wifi.dispose);
    addTearDown(fake.close);
    await wifi.initialize();
    expect(await wifi.host(), isTrue);
    expect(wifi.state.groupOwner, isTrue);
    expect(wifi.state.groupOwnerIp, '192.168.49.1');
    expect(wifi.busy, isFalse);
  });

  test('guest joins discovered peer and verifies ownership', () async {
    final fake = FakeWifiDirectPlatform();
    final wifi = WifiDirectController(platform: fake);
    addTearDown(wifi.dispose);
    addTearDown(fake.close);
    await wifi.initialize();
    expect(
        await wifi.joinPeer(const WifiDirectPeer(
          name: 'Host',
          address: 'aa:bb:cc:dd:ee:ff',
          status: 3,
        )),
        isTrue);
    expect(wifi.state.groupOwner, isFalse);
    expect(wifi.state.groupOwnerIp, '192.168.49.1');
  });

  test('permission denied does not attempt group creation', () async {
    final fake = FakeWifiDirectPlatform()..permissionAllowed = false;
    fake.current = const WifiDirectSnapshot(
      supported: true,
      wifiEnabled: true,
      permissionGranted: false,
    );
    final wifi = WifiDirectController(platform: fake);
    addTearDown(wifi.dispose);
    addTearDown(fake.close);
    await wifi.initialize();
    expect(await wifi.host(), isFalse);
    expect(wifi.error, contains('permission denied'));
    expect(fake.disconnects, 1);
  });

  test('group formation timeout cancels and removes stale group', () async {
    final fake = FakeWifiDirectPlatform()..formGroup = false;
    final wifi = WifiDirectController(
      platform: fake,
      groupTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(wifi.dispose);
    addTearDown(fake.close);
    await wifi.initialize();
    expect(await wifi.host(), isFalse);
    expect(wifi.error, contains('TimeoutException'));
    expect(fake.cancels, 1);
    expect(fake.disconnects, 1);
    expect(wifi.busy, isFalse);
  });

  test('simultaneous owners are rejected and group removed', () async {
    final fake = FakeWifiDirectPlatform()..wrongRole = true;
    final wifi = WifiDirectController(platform: fake);
    addTearDown(wifi.dispose);
    addTearDown(fake.close);
    await wifi.initialize();
    expect(
        await wifi.joinPeer(const WifiDirectPeer(
          name: 'Peer',
          address: 'aa:bb:cc:dd:ee:ff',
          status: 3,
        )),
        isFalse);
    expect(wifi.error, contains('Unexpected group ownership'));
    expect(fake.disconnects, 1);
  });

  test('lost Wi-Fi Direct group raises callback without inventing a route',
      () async {
    final fake = FakeWifiDirectPlatform();
    final wifi = WifiDirectController(platform: fake);
    addTearDown(wifi.dispose);
    addTearDown(fake.close);
    await wifi.initialize();
    await wifi.host();
    var lost = 0;
    wifi.onGroupLost = () => lost++;
    fake.publish(const WifiDirectSnapshot(
      supported: true,
      wifiEnabled: false,
      permissionGranted: true,
    ));
    expect(lost, 1);
    expect(wifi.state.connected, isFalse);
    expect(wifi.state.groupOwnerIp, isNull);
  });
}
