import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:block_drop/main.dart';
import 'package:block_drop/widgets/game_board.dart';
import 'package:block_drop/widgets/hold_piece_display.dart';
import 'package:block_drop/screens/tetris_game_screen.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Widget Integration Tests', () {
    testWidgets('all HUD labels are visible on startup', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());
      await tester.pump();

      expect(find.textContaining('Score:'), findsOneWidget);
      expect(find.textContaining('Level:'), findsOneWidget);
      expect(find.textContaining('Lines:'), findsOneWidget);
      expect(find.text('Hold:'), findsOneWidget);
      expect(find.text('Next:'), findsOneWidget);
    });

    testWidgets('settings screen opens with expected options', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // AppBar title
      expect(find.text('Settings'), findsOneWidget);

      // Game control buttons
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);

      // Sound settings
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Sound Effects'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Large Board'), 100);
      expect(find.text('Large Board'), findsOneWidget);

      // Multiplayer entry (may require scrolling on small test screens)
      await tester.scrollUntilVisible(find.text('Play on LAN'), 100);
      expect(find.text('Play on LAN'), findsOneWidget);
    });

    testWidgets('large board setting uses the fullscreen game layout', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await settings.setFullscreenBoard(true);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => SharedPreferences.setMockInitialValues({}));

      await tester.pumpWidget(
        MaterialApp(home: TetrisGameScreen(settings: settings)),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('fullscreen-game-board')),
        findsOneWidget,
      );
      expect(find.text('HOLD'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
      expect(tester.getSize(find.byType(GameBoard)).height, greaterThan(790));
    });

    testWidgets('on-screen soft drop respects the disabled gameplay rule', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await settings.setShowOnScreenControls(true);
      await settings.setGameplaySettings(
        settings.gameplay.copyWith(softDropEnabled: false),
      );
      addTearDown(() => SharedPreferences.setMockInitialValues({}));

      await tester.pumpWidget(
        MaterialApp(home: TetrisGameScreen(settings: settings)),
      );
      await tester.pump(const Duration(milliseconds: 250));

      final gameLogic =
          tester.widget<GameBoard>(find.byType(GameBoard)).gameLogic;
      gameLogic.gameTimer?.cancel();
      gameLogic.isNewPieceGracePeriod = false;
      final startingY = gameLogic.currentY;

      await tester.tap(find.byKey(const Key('soft-drop-control')));
      await tester.pump();

      expect(gameLogic.currentY, startingY);
    });

    testWidgets('Resume button in settings returns to the game', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      // Back on the game screen — HUD labels must be visible again
      expect(find.textContaining('Score:'), findsOneWidget);
      expect(find.text('Hold:'), findsOneWidget);
      expect(find.text('Next:'), findsOneWidget);
    });

    testWidgets('tapping the Hold label holds the current piece', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());
      await tester.pump();

      // "Hold:" is inside a GestureDetector — tapping it triggers holdPiece()
      await tester.tap(find.text('Hold:'));
      await tester.pump();

      // Game is still running and HUD is intact
      expect(find.textContaining('Score:'), findsOneWidget);
      expect(find.text('Hold:'), findsOneWidget);
      expect(find.text('Next:'), findsOneWidget);
    });

    testWidgets('hold preview availability resets after the piece locks', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());
      await tester.pump();

      await tester.tap(find.text('Hold:'));
      await tester.pump();

      HoldPieceDisplay holdPreview = tester.widget(
        find.byType(HoldPieceDisplay),
      );
      expect(holdPreview.isAvailable, isFalse);

      await tester.pump(const Duration(milliseconds: 201));
      final gameLogic =
          tester.widget<GameBoard>(find.byType(GameBoard)).gameLogic;
      gameLogic.dropPiece();
      await tester.pump();

      holdPreview = tester.widget(find.byType(HoldPieceDisplay));
      expect(holdPreview.isAvailable, isTrue);
    });

    testWidgets(
      'downward drag with horizontal drift does not move piece sideways',
      (WidgetTester tester) async {
        await tester.pumpWidget(const TetrisApp());
        // Wait for grace period to expire
        await tester.pump(const Duration(milliseconds: 500));

        final gameLogic =
            tester.widget<GameBoard>(find.byType(GameBoard)).gameLogic;
        final int startX = gameLogic.currentX;

        // Simulate dragging mostly downward but with horizontal drift —
        // the exact motion that previously caused the piece to slide sideways.
        // Total: dy=120, dx=25 (primarily down).
        final center = tester.getCenter(find.byType(GameBoard));
        final gesture = await tester.startGesture(center);
        for (int i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(-2.5, 12));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pump();

        expect(
          gameLogic.currentX,
          startX,
          reason:
              'Piece should not move horizontally when gesture is primarily downward',
        );
      },
    );

    testWidgets(
      'horizontal drag with slight vertical drift moves piece sideways',
      (WidgetTester tester) async {
        await tester.pumpWidget(const TetrisApp());
        await tester.pump(const Duration(milliseconds: 500));

        final gameLogic =
            tester.widget<GameBoard>(find.byType(GameBoard)).gameLogic;
        final int startX = gameLogic.currentX;

        // Simulate dragging mostly rightward — should move piece right.
        // Total: dx=120, dy=6 (primarily horizontal).
        final center = tester.getCenter(find.byType(GameBoard));
        final gesture = await tester.startGesture(center);
        for (int i = 0; i < 6; i++) {
          await gesture.moveBy(const Offset(20, 1));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pump();

        expect(
          gameLogic.currentX,
          greaterThan(startX),
          reason: 'Piece should move right on a rightward horizontal drag',
        );
      },
    );

    testWidgets('horizontal drag distance maps directly to board columns', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());
      await tester.pump(const Duration(milliseconds: 500));

      final gameLogic =
          tester.widget<GameBoard>(find.byType(GameBoard)).gameLogic;
      final int startX = gameLogic.currentX;
      final center = tester.getCenter(find.byType(GameBoard));
      final gesture = await tester.startGesture(center);

      await gesture.moveBy(const Offset(-54, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-1, 0));
      await tester.pump();
      expect(gameLogic.currentX, startX - 3);

      await gesture.moveBy(const Offset(19, 0));
      await tester.pump();
      expect(gameLogic.currentX, startX - 2);

      await gesture.up();
    });
  });
}
