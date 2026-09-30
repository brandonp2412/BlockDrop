import 'package:block_drop/screens/settings_screen.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('clear sound selector is not exposed in settings',
      (tester) async {
    final settings = SettingsProvider();

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );
    await tester.pump();

    expect(find.byKey(const Key('settingsClearEffectPack')), findsNothing);
    expect(find.text('Clear Sound'), findsNothing);
  });
}
