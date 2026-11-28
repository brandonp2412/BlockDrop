import 'package:block_drop/constants/game_constants.dart';
import 'package:block_drop/game/game_logic.dart';
import 'package:block_drop/main.dart';
import 'package:block_drop/models/tetromino.dart';
import 'package:block_drop/multiplayer/multiplayer_manager.dart';
import 'package:block_drop/screens/multiplayer_game_screen.dart';
import 'package:block_drop/screens/whats_new_screen.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:block_drop/widgets/game_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture the Block Drop screenshot catalogue', (tester) async {
    try {
      await _captureCatalogue(tester, binding);
    } catch (error, stack) {
      binding.reportData ??= {};
      binding.reportData!['catalogueError'] = '$error\n$stack';
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Future<void> _captureCatalogue(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  final settings = SettingsProvider(isTelevision: () async => false);
  await settings.load();
  await settings.setLocaleCode('en');
  await settings.setThemeMode(AppThemeMode.dark);
  await settings.setStyle(AppStyle.modern);
  await settings.setContinueGameEnabled(false);
  await tester.pumpWidget(BlockDropApp(settings: settings));

  Future<void> capture(String name) async {
    await tester.pumpAndSettle();
    final error = tester.takeException();
    if (error != null) throw StateError('$name: $error');
    await binding.takeScreenshot(name);
  }

  Future<void> tap(Finder target) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> closeRoute() async {
    final context = tester.element(find.byType(Scaffold).last);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
  }

  Future<void> openPage(Widget page) async {
    final context = tester.element(find.byType(GameBoard));
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  Future<void> search(String query) async {
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.text = query;
    field.onChanged!(query);
    await tester.pumpAndSettle();
  }

  GameLogic game() =>
      tester.widget<GameBoard>(find.byType(GameBoard)).gameLogic;

  await tester.pumpAndSettle();
  final preview = GameLogic()..startGame();
  preview.currentPiece = Tetromino.pieces[2];
  preview.nextPiece = Tetromino.pieces[0];
  preview.heldPiece = Tetromino.pieces[1];
  preview.currentX = 3;
  preview.currentY = GameConstants.previewRows + 4;
  preview.score = 2480;
  preview.level = 3;
  preview.linesCleared = 23;
  preview.dropSpeed = 10000;
  const stack = [
    '.......LL.',
    '..T...LLSS',
    '.TTT..JSSO',
    'ZZ...JJJOO',
    'IZZZ..O.OO',
    'IIIJ..OOJJ',
  ];
  for (final (index, row) in stack.indexed) {
    final colors = preview.board[preview.board.length - stack.length + index];
    for (var column = 0; column < row.length; column++) {
      final piece = 'IOTSZJL'.indexOf(row[column]);
      colors[column] = piece < 0 ? null : Tetromino.pieces[piece].color;
    }
  }
  final snapshot = preview.createSnapshot();
  preview.dispose();

  void restoreBoard() {
    final logic = game();
    expect(logic.restoreSnapshot(snapshot), isTrue);
    logic.gameTimer?.cancel();
  }

  for (final theme in [
    AppThemeMode.light,
    AppThemeMode.dark,
    AppThemeMode.black
  ]) {
    await settings.setThemeMode(theme);
    for (final style in AppStyle.values) {
      if (theme == AppThemeMode.light && style == AppStyle.neon) continue;
      await settings.setStyle(style);
      restoreBoard();
      await capture('${theme.name}-${style.name}');
    }
  }

  await settings.setThemeMode(AppThemeMode.dark);
  await settings.setStyle(AppStyle.modern);
  await settings.setShowOnScreenControls(true);
  await capture('on-screen-controls');
  if (tester.view.physicalSize.aspectRatio <= 1.4) {
    await settings.setFullscreenBoard(true);
    await capture('full-screen-board');
    await settings.setFullscreenBoard(false);
  }
  await settings.setShowOnScreenControls(false);

  await tap(find.widgetWithIcon(IconButton, Icons.settings));
  await capture('settings');
  for (final (query, name) in [
    ('Appearance', 'appearance-settings'),
    ('Gameplay', 'gameplay-settings'),
    ('Sound', 'sound-settings'),
    ('Controller', 'controller-settings'),
    ('Instructions', 'instructions'),
    ('About', 'about'),
    ('zzz', 'settings-no-results'),
  ]) {
    await search(query);
    await capture(name);
  }

  await search('Style');
  await tap(find.widgetWithText(TextButton, 'Modern'));
  await capture('style-picker');
  await closeRoute();
  await search('Starting Speed');
  await tap(find.widgetWithText(TextButton, '800 ms'));
  await capture('starting-speed');
  await closeRoute();

  await search('Practice Mode');
  await tap(find.byIcon(Icons.school));
  await capture('practice-level-picker');
  await tap(find.byIcon(Icons.add));
  await tap(find.widgetWithText(FilledButton, 'Start'));
  game().gameTimer?.cancel();
  await capture('practice-game');

  restoreBoard();
  HardwareKeyboard.instance.handleKeyEvent(
    const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyQ,
      logicalKey: LogicalKeyboardKey.keyQ,
      timeStamp: Duration.zero,
    ),
  );
  HardwareKeyboard.instance.handleKeyEvent(
    const KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.keyQ,
      logicalKey: LogicalKeyboardKey.keyQ,
      timeStamp: Duration.zero,
    ),
  );
  await capture('quit-confirmation');
  await closeRoute();

  final logic = game();
  for (final row in logic.board.skip(GameConstants.previewRows).take(2)) {
    row.fillRange(0, row.length, Colors.blue);
  }
  logic.spawnNewPiece();
  await capture('game-over');
  await closeRoute();

  await openPage(const WhatsNewScreen());
  await capture('whats-new');
  await closeRoute();

  // Unmounting releases the listener for this socket-free fixture. The
  // manager’s native teardown checks dart:io platform properties.
  final manager = MultiplayerManager(playerName: 'Player')
    ..opponentName = 'Rival'
    ..opponentScore = 1950
    ..opponentLines = 17
    ..opponentBoard = [
      ...List.filled(
        (GameConstants.boardHeight - stack.length) * GameConstants.boardWidth,
        0,
      ),
      for (final row in stack)
        for (final cell in row.split('').reversed) 'IOTSZJL'.indexOf(cell) + 1,
    ];
  await settings.setShowOpponentBoard(true);
  manager.state = MultiplayerState.inGame;
  await openPage(MultiplayerGameScreen(manager: manager, settings: settings));
  await capture('multiplayer-countdown');
  await tester.pump(const Duration(seconds: 3));
  restoreBoard();
  await capture('multiplayer-match');

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  settings.dispose();
}
