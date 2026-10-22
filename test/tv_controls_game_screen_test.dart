import 'package:block_drop/screens/block_drop_game_screen.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:block_drop/widgets/game_board.dart';
import 'package:block_drop/widgets/on_screen_game_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final screenSize in [const Size(960, 540), const Size(1920, 1080)]) {
    testWidgets('TV controls are visible and playable at $screenSize', (
      tester,
    ) async {
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsProvider(isTelevision: () async => true);
      await settings.load();
      expect(settings.showOnScreenControls, isTrue);
      await tester.pumpWidget(
        MaterialApp(home: BlockDropGameScreen(settings: settings)),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(OnScreenGameControls), findsOneWidget);
      final board = tester.getRect(find.byType(GameBoard));
      const controlIds = [
        'move-left-control',
        'move-right-control',
        'soft-drop-control',
        'hard-drop-control',
        'rotate-left-control',
        'rotate-right-control',
        'hold-control',
      ];
      for (final id in controlIds) {
        final rect = tester.getRect(find.byKey(Key(id)));
        expect(rect.left, greaterThanOrEqualTo(0), reason: id);
        expect(rect.top, greaterThanOrEqualTo(0), reason: id);
        expect(rect.right, lessThanOrEqualTo(screenSize.width), reason: id);
        expect(rect.bottom, lessThanOrEqualTo(screenSize.height), reason: id);
      }
      expect(tester.getRect(find.byKey(const Key('move-left-control'))).right,
          lessThan(board.left));
      expect(tester.getRect(find.byKey(const Key('rotate-right-control'))).left,
          greaterThan(board.right));

      final game = tester.widget<GameBoard>(find.byType(GameBoard)).gameLogic;
      game.gameTimer?.cancel();
      game.isNewPieceGracePeriod = false;
      final originalX = game.currentX;
      await tester.tap(find.byKey(const Key('move-left-control')));
      await tester.pump();
      expect(game.currentX, originalX - 1);
      await tester.tap(find.byKey(const Key('move-right-control')));
      await tester.pump();
      expect(game.currentX, originalX);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('explicitly disabled TV controls stay hidden until enabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'show_on_screen_controls': false});
    final settings = SettingsProvider(isTelevision: () async => true);
    await settings.load();
    await tester.pumpWidget(
      MaterialApp(home: BlockDropGameScreen(settings: settings)),
    );
    await tester.pump();
    expect(find.byType(OnScreenGameControls), findsNothing);

    await settings.setShowOnScreenControls(true);
    await tester.pump();
    expect(find.byType(OnScreenGameControls), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
