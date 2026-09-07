import 'package:block_drop/screens/settings_screen.dart';
import 'package:block_drop/settings/controller_bindings.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows an editable binding for every gameplay action', (
    tester,
  ) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );

    for (final action in GameplayAction.values) {
      final actionLabel = find.text(action.label);
      await tester.scrollUntilVisible(actionLabel, 120);
      expect(actionLabel, findsOneWidget);
    }
    final resetButton = find.text('Reset controller layout');
    await tester.scrollUntilVisible(resetButton, 120);
    expect(resetButton, findsOneWidget);
  });

  testWidgets('filters settings by the search query', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );

    await tester.tap(find.byTooltip('Search settings'));
    await tester.pump();
    expect(find.text('Search settings'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'music');
    await tester.pump();

    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Sound Effects'), findsNothing);
    expect(find.text('Ghost Tile'), findsNothing);
    expect(find.text('Large Board'), findsNothing);
    expect(find.text('Show Opponent Board'), findsNothing);
  });

  testWidgets('search finds settings outside the sound section', (
    tester,
  ) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );

    await tester.tap(find.byTooltip('Search settings'));
    await tester.pump();
    expect(find.text('Search settings'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'large board');
    await tester.pump();

    expect(find.text('Large Board'), findsOneWidget);
    expect(find.text('Music'), findsNothing);
    expect(find.text('Ghost Tile'), findsNothing);
    expect(find.text('Show Opponent Board'), findsNothing);
  });

  testWidgets('binding button opens controller input prompt', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );
    final binding = find.text('Button A');
    await tester.scrollUntilVisible(binding, 120);
    await Scrollable.ensureVisible(tester.element(binding), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(binding);
    await tester.pumpAndSettle();

    expect(find.text('Bind Rotate right'), findsOneWidget);
    expect(find.textContaining('connected controller'), findsOneWidget);
  });
}
