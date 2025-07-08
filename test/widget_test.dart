import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:block_drop/main.dart';
import 'package:block_drop/widgets/game_board.dart';
import 'package:block_drop/widgets/next_piece_display.dart';
import 'package:block_drop/widgets/hold_piece_display.dart';
import 'package:block_drop/screens/tetris_game_screen.dart';

void main() {
  group('Block Drop App Tests', () {
    testWidgets('App should initialize correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const TetrisApp());

      // Verify that our Block Drop game starts with correct initial values
      expect(find.text('Score: 0'), findsOneWidget);
      expect(find.text('Level: 1'), findsOneWidget);
      expect(find.text('Lines: 0'), findsOneWidget);

      // Verify that all essential game components are present
      expect(find.byType(TetrisGameScreen), findsOneWidget);
      expect(find.byType(GameBoard), findsOneWidget);
      expect(find.byType(NextPieceDisplay), findsOneWidget);
      expect(find.byType(HoldPieceDisplay), findsOneWidget);

      // Verify UI labels are present
      expect(find.text('Hold:'), findsOneWidget);
      expect(find.text('Next:'), findsOneWidget);
    });

    testWidgets('App should have correct theme and configuration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      // Find the MaterialApp widget
      final MaterialApp app = tester.widget(find.byType(MaterialApp));

      // Verify app configuration
      expect(app.title, 'Block Drop - Tetris');
      expect(app.debugShowCheckedModeBanner, false);
      expect(app.theme?.scaffoldBackgroundColor, Colors.black);
    });

    testWidgets('Game should not show game over initially', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      // Game over elements should not be visible at start
      expect(find.text('Game Over!'), findsNothing);
      expect(find.text('Restart'), findsNothing);
    });

    testWidgets('App should handle multiple pumps without errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      // Pump multiple times to simulate frame updates
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify the app is still functional
      expect(find.byType(TetrisGameScreen), findsOneWidget);
      expect(find.byType(GameBoard), findsOneWidget);
      expect(find.textContaining('Score:'), findsOneWidget);
    });

    testWidgets('Essential widgets should be findable by type', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      // Test that we can find all the essential widget types
      // This ensures the widget tree is structured correctly
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);
      expect(
        find.byType(Focus),
        findsAtLeastNWidgets(1),
      ); // Multiple Focus widgets are normal
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Column), findsAtLeastNWidgets(1));
      expect(find.byType(Row), findsAtLeastNWidgets(1));
    });
  });
}
