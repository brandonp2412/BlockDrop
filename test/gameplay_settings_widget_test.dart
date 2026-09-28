import 'package:block_drop/screens/settings_screen.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('gameplay settings expose every configurable match rule',
      (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );

    await tester.tap(find.byKey(const ValueKey('settings-search-button')));
    await tester.pump();

    for (final label in [
      'Starting Speed',
      'Speed per Level',
      'Maximum Level',
      'Lines per Level',
      'Enable Soft Drop',
      'Swipe Up to Hold',
      'Continue Saved Game',
      'Back Gesture Holds',
    ]) {
      await tester.enterText(
        find.byKey(const ValueKey('settings-search')),
        label,
      );
      await tester.pump();
      expect(find.text(label), findsNWidgets(2));
    }
  });

  testWidgets('language picker exposes and persists explicit locale override',
      (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('settingsLanguageDropdown')),
      120,
    );
    await tester.tap(find.byKey(const Key('settingsLanguageDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếng Việt').last);
    await tester.pump();

    expect(settings.localeCode, 'vi');
  });

  testWidgets('language picker exposes Traditional Chinese', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('settingsLanguageDropdown')),
      120,
    );
    await tester.tap(find.byKey(const Key('settingsLanguageDropdown')));
    await tester.pumpAndSettle();

    expect(find.text('中文（简体）'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(find.text('中文（繁體）'), findsOneWidget);
  });

  testWidgets('maximum level picker offers unlimited progression',
      (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );

    await tester.scrollUntilVisible(find.text('Maximum Level'), 120);
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();

    expect(
        find.text('Choose 0 for unlimited level progression.'), findsOneWidget);
  });
}
