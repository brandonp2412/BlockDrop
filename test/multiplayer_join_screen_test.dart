import 'package:block_drop/multiplayer/multiplayer_manager.dart';
import 'package:block_drop/screens/multiplayer_join_screen.dart';
import 'package:block_drop/screens/multiplayer_qr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitFor(WidgetTester tester, bool Function() predicate) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 80 && !predicate(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  });
  await tester.pump();
  expect(predicate(), isTrue);
}

Future<void> showJoin(
  WidgetTester tester,
  MultiplayerManager guest, {
  Future<String?> Function(BuildContext)? scan,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => MultiplayerJoinScreen(
                manager: guest,
                scanInvitation: scan,
              ),
            ),
          ),
          child: const Text('Open join'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open join'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('manual IP and pairing token reach the host without UDP',
      (tester) async {
    final host = MultiplayerManager(playerName: 'Host');
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    await host.startHosting(port: 0);
    final invite = host.hostingInvite('127.0.0.1');

    await showJoin(tester, guest);
    await tester.enterText(find.byKey(const Key('join-address')), invite.host);
    await tester.enterText(
      find.byKey(const Key('join-port')),
      invite.port.toString(),
    );
    await tester.ensureVisible(find.byKey(const Key('join-token')));
    await tester.enterText(find.byKey(const Key('join-token')), invite.token);
    await tester.ensureVisible(find.byKey(const Key('join-manual')));
    await tester.tap(find.byKey(const Key('join-manual')));
    await tester.pump();
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 250)));
    await waitFor(tester, () => host.state == MultiplayerState.invited);
    host.acceptInvite();
    await waitFor(tester, () => guest.state == MultiplayerState.inLobby);
    expect(host.isHost, isTrue);
    expect(guest.isHost, isFalse);
  });

  testWidgets('scanned QR uses the same direct TCP guest path', (tester) async {
    final host = MultiplayerManager(playerName: 'Host');
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    await host.startHosting(port: 0);
    final invite = host.hostingInvite('127.0.0.1');
    await showJoin(
      tester,
      guest,
      scan: (_) async => invite.toUri().toString(),
    );
    await tester.tap(find.byKey(const Key('scan-join-qr')));
    await tester.pump();
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 250)));
    await waitFor(tester, () => host.state == MultiplayerState.invited);
    host.acceptInvite();
    await waitFor(tester, () => guest.state == MultiplayerState.inLobby);
  });

  testWidgets('expired QR and malformed manual inputs do not connect',
      (tester) async {
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(guest.dispose);
    await showJoin(tester, guest);
    await tester.ensureVisible(find.byKey(const Key('join-manual')));
    await tester.tap(find.byKey(const Key('join-manual')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-error')), findsOneWidget);
    expect(guest.state, MultiplayerState.idle);

    const code =
        'blockdrop://join?v=1&host=127.0.0.1&port=45679&token=abcdef0123456789abcdef0123456789abcdef0123456789&exp=1';
    await tester.ensureVisible(find.byKey(const Key('join-code')));
    await tester.enterText(find.byKey(const Key('join-code')), code);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('join-with-code')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('join-with-code')));
    await tester.pumpAndSettle();
    expect(find.textContaining('expired'), findsOneWidget);
    expect(guest.state, MultiplayerState.idle);
  });

  testWidgets('cancelled scan leaves manual join available', (tester) async {
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(guest.dispose);
    await showJoin(tester, guest, scan: (_) async => null);
    await tester.tap(find.byKey(const Key('scan-join-qr')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-address')), findsOneWidget);
    expect(find.byKey(const Key('join-manual')), findsOneWidget);
    expect(guest.state, MultiplayerState.idle);
  });

  testWidgets('camera denied shows truthful manual fallback', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MultiplayerQrScannerScreen(
        readerBuilder: (onDetected, unavailable) => Center(
          child: FilledButton(
            onPressed: unavailable,
            child: const Text('Deny camera'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Deny camera'));
    await tester.pump();
    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.text('Enter details manually'), findsOneWidget);
  });

  testWidgets('scanner rejects unrelated QR contents', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MultiplayerQrScannerScreen(
        readerBuilder: (onDetected, unavailable) => Center(
          child: FilledButton(
            onPressed: () => onDetected('https://example.org'),
            child: const Text('Scan unrelated QR'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Scan unrelated QR'));
    await tester.pump();
    expect(find.textContaining('Not a valid'), findsOneWidget);
  });

  testWidgets('invalid scanned code shows error without joining',
      (tester) async {
    final guest = MultiplayerManager(playerName: 'Guest');
    addTearDown(guest.dispose);
    await showJoin(tester, guest, scan: (_) async => 'not-a-blockdrop-code');
    await tester.tap(find.byKey(const Key('scan-join-qr')));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('join-error')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('join-error')), findsOneWidget);
    expect(guest.state, MultiplayerState.idle);
  });
}
