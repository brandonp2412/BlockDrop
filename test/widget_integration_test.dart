import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:block_drop/main.dart';
import 'package:block_drop/screens/tetris_game_screen.dart';
import 'package:block_drop/widgets/game_board.dart';
import 'package:block_drop/widgets/next_piece_display.dart';
import 'package:block_drop/widgets/hold_piece_display.dart';

void main() {
  group('Widget Integration Tests', () {
    testWidgets('App should start with correct initial state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      // Verify app title and theme
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.title, 'Block Drop - Tetris');
      expect(app.debugShowCheckedModeBanner, false);

      // Verify initial game state
      expect(find.text('Score: 0'), findsOneWidget);
      expect(find.text('Level: 1'), findsOneWidget);
      expect(find.text('Lines: 0'), findsOneWidget);

      // Verify game components are present
      expect(find.byType(TetrisGameScreen), findsOneWidget);
      expect(find.byType(GameBoard), findsOneWidget);
      expect(find.byType(NextPieceDisplay), findsOneWidget);
      expect(find.byType(HoldPieceDisplay), findsOneWidget);

      // Verify hold and next piece labels
      expect(find.text('Hold:'), findsOneWidget);
      expect(find.text('Next:'), findsOneWidget);

      // Game over should not be visible initially
      expect(find.text('Game Over!'), findsNothing);
      expect(find.text('Restart'), findsNothing);
    });

    testWidgets('Hold piece tap should work', (WidgetTester tester) async {
      await tester.pumpWidget(const TetrisApp());

      await tester.pump();

      // Find and tap the hold piece area
      final holdPieceDisplay = find.byType(HoldPieceDisplay);
      expect(holdPieceDisplay, findsOneWidget);

      // Tap the hold area (it's wrapped in a GestureDetector)
      await tester.tap(holdPieceDisplay);
      await tester.pump();

      // The tap should work without errors - we can't verify internal state
      // but we can verify the UI doesn't crash
      expect(find.byType(TetrisGameScreen), findsOneWidget);
    });

    testWidgets('Game board should be properly sized and bordered', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      await tester.pump();

      // Find the game board container
      final gameBoardContainer = find
          .ancestor(
            of: find.byType(GameBoard),
            matching: find.byType(Container),
          )
          .first;

      final Container container = tester.widget(gameBoardContainer);

      // Verify border exists
      expect(container.decoration, isA<BoxDecoration>());
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.border, isA<Border>());

      final Border border = decoration.border as Border;
      expect(border.top.color, Colors.white);
      expect(border.top.width, 2);
    });

    testWidgets('Next and Hold piece displays should have borders', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      await tester.pump();

      // Find containers for next and hold pieces
      final containers = find.byType(Container);

      // Look for containers with borders (next and hold piece containers)
      bool foundBorderedContainers = false;
      for (int i = 0; i < tester.widgetList(containers).length; i++) {
        final Container container = tester.widget(containers.at(i));
        if (container.decoration is BoxDecoration) {
          final BoxDecoration decoration =
              container.decoration as BoxDecoration;
          if (decoration.border != null) {
            foundBorderedContainers = true;
            expect(decoration.border, isA<Border>());
          }
        }
      }

      expect(foundBorderedContainers, true);
    });

    testWidgets('App should handle keyboard focus correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      await tester.pump();

      // Verify Focus widgets exist (there may be multiple)
      final focusWidgets = find.byType(Focus);
      expect(focusWidgets, findsAtLeastNWidgets(1));

      // Find the autofocus widget specifically
      bool foundAutofocus = false;
      for (int i = 0; i < tester.widgetList(focusWidgets).length; i++) {
        final Focus focus = tester.widget(focusWidgets.at(i));
        if (focus.autofocus) {
          foundAutofocus = true;
          break;
        }
      }
      expect(foundAutofocus, true);
    });

    testWidgets('Game should handle basic screen size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());
      await tester.pump();

      // Verify game board exists and renders without overflow
      expect(find.byType(GameBoard), findsOneWidget);
      expect(find.byType(TetrisGameScreen), findsOneWidget);
    });

    testWidgets('SingleChildScrollView should be present for scrolling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      await tester.pump();

      // Verify SingleChildScrollView exists for handling overflow
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('All required text labels should be present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      await tester.pump();

      // Verify all expected text labels exist
      expect(find.textContaining('Score:'), findsOneWidget);
      expect(find.textContaining('Level:'), findsOneWidget);
      expect(find.textContaining('Lines:'), findsOneWidget);
      expect(find.text('Hold:'), findsOneWidget);
      expect(find.text('Next:'), findsOneWidget);
    });

    testWidgets('Game should handle widget rebuilds without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      await tester.pump();

      // Trigger multiple rebuilds
      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }

      // Verify the game is still running and UI is intact
      expect(find.byType(TetrisGameScreen), findsOneWidget);
      expect(find.byType(GameBoard), findsOneWidget);
      expect(find.textContaining('Score:'), findsOneWidget);
    });
  });
}
