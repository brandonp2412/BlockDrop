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

    for (final label in [
      'Starting Speed',
      'Speed per Level',
      'Maximum Level',
      'Lines per Level',
      'Enable Soft Drop',
      'Back Gesture Holds',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 120);
      expect(find.text(label), findsOneWidget);
    }
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
