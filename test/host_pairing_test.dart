import 'package:block_drop/multiplayer/direct_join_invite.dart';
import 'package:block_drop/multiplayer/lan_network.dart';
import 'package:block_drop/multiplayer/multiplayer_manager.dart';
import 'package:block_drop/screens/multiplayer_host_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QR payload round-trips version, address, port, name, token and expiry',
      () {
    final expiry = DateTime.fromMillisecondsSinceEpoch(1900000000000);
    const token = 'abcdef0123456789abcdef0123456789abcdef0123456789';
    final invite = DirectJoinInvite(
      host: '192.168.1.22',
      port: 45679,
      token: token,
      displayName: 'Local host',
      expiresAt: expiry,
    );
    final encoded = invite.toUri().toString();
    expect(encoded, startsWith('blockdrop://join?'));
    expect(encoded, isNot(contains('http')));
    final decoded = DirectJoinInvite.fromUri(encoded);
    expect(decoded.host, '192.168.1.22');
    expect(decoded.port, 45679);
    expect(decoded.token, token);
    expect(decoded.displayName, 'Local host');
    expect(decoded.expiresAt, expiry);
    expect(() => DirectJoinInvite.fromUri(encoded.replaceFirst('v=1', 'v=2')),
        throwsFormatException);
    expect(
        () => DirectJoinInvite.fromUri(
            encoded.replaceFirst('192.168.1.22', 'remote.example')),
        throwsFormatException);
  });

  test('Linux addresses use physical interface and real prefix', () {
    const output = '''
    [
      {"ifname":"docker0","flags":["UP","LOWER_UP"],"addr_info":[{"scope":"global","local":"172.17.0.1","prefixlen":16}]},
      {"ifname":"enp5s0","flags":["UP","LOWER_UP"],"addr_info":[{"scope":"global","local":"192.168.1.22","prefixlen":23}]}
    ]
    ''';
    final lan = LanNetwork.fromLinuxIpJson(output);
    expect(lan?.ip, '192.168.1.22');
    expect(lan?.prefixLength, 23);
    expect(lan?.broadcast, '192.168.1.255');
    expect(
      LanNetwork.fromLinuxIpJson(
        '[{"ifname":"wg0","flags":["UP","LOWER_UP"],"addr_info":[]}]',
      ),
      isNull,
    );
  });

  test('macOS active ethernet prefix is parsed from netmask', () {
    const output = '''
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    inet 192.168.5.10 netmask 0xfffffc00 broadcast 192.168.7.255
    status: active
    ''';
    final lan = LanNetwork.fromMacIfconfig(output);
    expect(lan?.ip, '192.168.5.10');
    expect(lan?.prefixLength, 22);
  });

  testWidgets('host QR is local, copyable and regenerates', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final manager = MultiplayerManager(playerName: 'Host');
    addTearDown(manager.dispose);
    await manager.startHosting(port: 0);
    var lan = const LanAddress(ip: '192.168.1.22', prefixLength: 24);

    await tester.pumpWidget(MaterialApp(
      home: MultiplayerHostScreen(
        manager: manager,
        detectLan: () async => lan,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-qr')), findsOneWidget);
    expect(find.byKey(const Key('copy-join-code')), findsOneWidget);
    final code = tester
        .widget<SelectableText>(
          find.byKey(const Key('host-join-code')),
        )
        .data!;
    final invite = DirectJoinInvite.fromUri(code);
    expect(invite.host, '192.168.1.22');
    expect(invite.port, manager.hostingPort);
    expect(invite.displayName, 'Host');
    expect(invite.expiresAt, isNotNull);

    await tester.ensureVisible(find.byKey(const Key('refresh-invite')));
    await tester.tap(find.byKey(const Key('refresh-invite')));
    await tester.pumpAndSettle();
    final changed = tester
        .widget<SelectableText>(
          find.byKey(const Key('host-join-code')),
        )
        .data!;
    expect(DirectJoinInvite.fromUri(changed).token, isNot(invite.token));

    lan = const LanAddress(ip: '192.168.2.44', prefixLength: 23);
    await tester.ensureVisible(find.byKey(const Key('refresh-invite')));
    await tester.tap(find.byKey(const Key('refresh-invite')));
    await tester.pumpAndSettle();
    final refreshed = tester
        .widget<SelectableText>(
          find.byKey(const Key('host-join-code')),
        )
        .data!;
    expect(DirectJoinInvite.fromUri(refreshed).host, lan.ip);
  });

  testWidgets('missing LAN keeps a refresh path without inventing an IP',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final manager = MultiplayerManager(playerName: 'Host');
    addTearDown(manager.dispose);
    await manager.startHosting(port: 0);

    await tester.pumpWidget(MaterialApp(
      home: MultiplayerHostScreen(
        manager: manager,
        detectLan: () async => null,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-qr')), findsNothing);
    expect(find.textContaining('No physical Wi-Fi'), findsOneWidget);
    expect(find.byKey(const Key('refresh-invite')), findsOneWidget);
  });
}
