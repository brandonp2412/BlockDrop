import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:block_drop/main.dart';
import 'package:block_drop/settings/settings_provider.dart';

void main() {
  group('Block Drop App', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

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

    testWidgets('startup does not display a debug banner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const TetrisApp());

      expect(find.text('DEBUG'), findsNothing);
    });

    testWidgets('language override updates the app immediately', (
      WidgetTester tester,
    ) async {
      final settings = SettingsProvider();
      await tester.pumpWidget(TetrisApp(settings: settings));

      expect(find.text('Score: 0'), findsOneWidget);

      await settings.setLocaleCode('de');
      await tester.pump();

      expect(find.text('Punkte: 0'), findsOneWidget);
      expect(find.text('Score: 0'), findsNothing);
    });
  });
}
