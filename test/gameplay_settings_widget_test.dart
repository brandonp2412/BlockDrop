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

    expect(find.text('Starting Speed'), findsOneWidget);
    expect(find.text('Speed per Level'), findsOneWidget);
    expect(find.text('Maximum Level'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Lines per Level'), findsOneWidget);
    expect(find.text('Enable Soft Drop'), findsOneWidget);
    expect(find.text('Back Gesture Holds'), findsOneWidget);
  });

  testWidgets('maximum level picker offers unlimited progression',
      (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();

    expect(
        find.text('Choose 0 for unlimited level progression.'), findsOneWidget);
  });
}
