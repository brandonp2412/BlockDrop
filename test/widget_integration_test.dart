import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:block_drop/main.dart';
import 'package:block_drop/widgets/game_board.dart';

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

      // Multiplayer entry
      expect(find.text('Play on LAN'), findsOneWidget);
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
  });
}
