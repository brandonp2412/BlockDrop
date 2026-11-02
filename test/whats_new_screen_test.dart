import 'package:block_drop/l10n/app_localizations.dart';
import 'package:block_drop/screens/whats_new_screen.dart';
import 'package:block_drop/update_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('bundled release notes contain useful version history', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where((path) =>
            path.startsWith('assets/changelogs/') && path.endsWith('.txt'))
        .toList();

    expect(paths, hasLength(12));
    expect(paths, contains('assets/changelogs/1.0.74.txt'));
    expect(await rootBundle.loadString('assets/changelogs/1.0.74.txt'),
        contains('Multiplayer discovery'));
  });

  testWidgets('update notice switch persists its disabled state',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const app = MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: WhatsNewScreen(),
    );
    await tester.pumpWidget(app);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text('Version 1.0.74'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);

    await tester.tap(find.text('Show update notices'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(showUpdateNoticesKey), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
  });
}
