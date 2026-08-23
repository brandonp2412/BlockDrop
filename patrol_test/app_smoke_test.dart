import 'package:block_drop/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('settings can be changed before resuming the game', ($) async {
    app.main();
    await $.pumpAndSettle();

    await $(Icons.settings).tap();
    await $.pumpAndSettle();

    expect($('Settings'), findsOneWidget);
    expect($('Music'), findsOneWidget);

    await $.tester.tap(find.byType(Switch).at(2));
    await $('Resume').tap();
    await $.pumpAndSettle();

    expect($(Icons.settings), findsWidgets);
    expect($('Settings'), findsNothing);
  });
}
