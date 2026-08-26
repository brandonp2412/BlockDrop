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
      final binding = find.byKey(Key('controller-binding-${action.name}'));
      await tester.scrollUntilVisible(binding, 120);
      expect(binding, findsOneWidget);
    }
    final resetButton = find.byKey(const Key('reset-controller-bindings'));
    await tester.scrollUntilVisible(resetButton, 120);
    expect(resetButton, findsOneWidget);
  });

  testWidgets('binding button opens controller input prompt', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );
    final binding = find.byKey(
      const Key('controller-binding-rotateRight'),
    );
    await tester.scrollUntilVisible(binding, 120);
    await Scrollable.ensureVisible(
      tester.element(binding),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(binding);
    await tester.pumpAndSettle();

    expect(find.text('Bind Rotate right'), findsOneWidget);
    expect(find.textContaining('connected controller'), findsOneWidget);
  });
}
