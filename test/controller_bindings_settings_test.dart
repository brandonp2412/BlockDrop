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
      await tester.scrollUntilVisible(
        actionLabel,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(actionLabel, findsOneWidget);
    }
    final resetButton = find.text('Reset controller layout');
    await tester.scrollUntilVisible(
      resetButton,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(resetButton, findsOneWidget);
  });

  testWidgets('filters settings by the search query', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );

    await tester.enterText(
      find.byKey(const ValueKey('settings-search')),
      'music',
    );
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

    await tester.enterText(
      find.byKey(const ValueKey('settings-search')),
      'large board',
    );
    await tester.pump();

    expect(find.text('Large Board'), findsOneWidget);
    expect(find.text('Music'), findsNothing);
    expect(find.text('Ghost Tile'), findsNothing);
    expect(find.text('Show Opponent Board'), findsNothing);
  });

  testWidgets('retro style reaches controller controls and preserves gaps', (
    tester,
  ) async {
    final settings = SettingsProvider();
    await settings.setStyle(AppStyle.retro);
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );

    final firstAction = GameplayAction.values[0];
    final secondAction = GameplayAction.values[1];
    final firstButtonFinder = find.byKey(
      Key('controller-binding-${firstAction.name}'),
    );
    final secondButtonFinder = find.byKey(
      Key('controller-binding-${secondAction.name}'),
    );
    await tester.scrollUntilVisible(
      firstButtonFinder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final firstButton = tester.widget<OutlinedButton>(firstButtonFinder);
    final shape = firstButton.style?.shape?.resolve({});
    expect(shape, isA<RoundedRectangleBorder>());
    expect((shape! as RoundedRectangleBorder).borderRadius, BorderRadius.zero);

    final side = firstButton.style?.side?.resolve({});
    expect(side?.width, 2);

    await tester.ensureVisible(secondButtonFinder);
    await tester.pumpAndSettle();
    final firstRect = tester.getRect(firstButtonFinder);
    final secondRect = tester.getRect(secondButtonFinder);
    expect(secondRect.top - firstRect.bottom, greaterThanOrEqualTo(6));

    await tester.ensureVisible(firstButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(firstButtonFinder);
    await tester.pumpAndSettle();
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final dialogShape = dialog.shape;
    expect(dialogShape, isA<RoundedRectangleBorder>());
    expect(
      (dialogShape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.zero,
    );
  });

  testWidgets('binding button opens controller input prompt', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );
    final binding = find.text('Button A');
    await tester.scrollUntilVisible(
      binding,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(binding), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(binding);
    await tester.pumpAndSettle();

    expect(find.text('Bind Rotate right'), findsOneWidget);
    expect(find.textContaining('connected controller'), findsOneWidget);
  });
}
