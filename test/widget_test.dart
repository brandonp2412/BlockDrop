import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:block_drop/main.dart';

void main() {
  group('Block Drop App', () {
    testWidgets('shows initial HUD stats at zero', (WidgetTester tester) async {
      await tester.pumpWidget(const TetrisApp());

      expect(find.text('Score: 0'), findsOneWidget);
      expect(find.text('Level: 1'), findsOneWidget);
      expect(find.text('Lines: 0'), findsOneWidget);
      expect(find.text('Hold:'), findsOneWidget);
      expect(find.text('Next:'), findsOneWidget);
    });

    testWidgets('does not show game-over UI on startup', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      expect(find.text('Game Over!'), findsNothing);
      expect(find.text('Play Again'), findsNothing);
    });

    testWidgets('HUD remains visible across multiple frame updates', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.textContaining('Score:'), findsOneWidget);
      expect(find.text('Hold:'), findsOneWidget);
      expect(find.text('Next:'), findsOneWidget);
    });

    testWidgets('production build has no debug banner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.debugShowCheckedModeBanner, false);
    });
  });
}
