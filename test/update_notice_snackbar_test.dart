import 'package:block_drop/l10n/app_localizations.dart';
import 'package:block_drop/update_notice_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [1280.0, 375.0, 320.0]) {
    testWidgets('new-version toast fits a $width-wide window', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var openedWhatsNew = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  newVersionSnackBar(
                    context,
                    '1.0.75',
                    () => openedWhatsNew = true,
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
      final rect = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      if (width >= 900) {
        expect(rect.width, 360);
        expect(rect.center.dx, closeTo(width / 2, 1));
      } else {
        expect(rect.width, greaterThan(0));
        expect(rect.width, lessThan(width));
      }
      expect(snackbar.persist, isFalse);
      expect(snackbar.duration, const Duration(seconds: 4));
      expect(find.text('New version 1.0.75'), findsOneWidget);
      await tester.tap(find.text("What's new"));
      expect(openedWhatsNew, isTrue);
    });
  }
}
