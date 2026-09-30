import 'package:block_drop/audio/sfx_pack.dart';
import 'package:block_drop/screens/settings_screen.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sound set selector exposes every bundled theme', (tester) async {
    final settings = SettingsProvider();

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: settings)),
    );
    await tester.pump();

    final selector = find.byKey(const Key('settingsSoundEffectPack'));
    expect(selector, findsOneWidget);

    final dropdown = tester.widget<DropdownButton<SoundEffectPack>>(selector);
    expect(dropdown.value, SoundEffectPack.classic);
    expect(dropdown.items, hasLength(SoundEffectPack.values.length));
    expect(SoundEffectPack.values, hasLength(14));
    expect(find.text('Sound Set'), findsOneWidget);
  });
}
