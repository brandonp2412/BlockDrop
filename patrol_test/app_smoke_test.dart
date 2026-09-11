import 'package:block_drop/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

const _uiTimeout = Duration(seconds: 15);

void main() {
  patrolTest('settings can be changed before resuming the game', ($) async {
    app.main();

    await $(Icons.settings).waitUntilVisible(timeout: _uiTimeout).tap();
    await $('Settings').waitUntilVisible(timeout: _uiTimeout);
    await $('Music').waitUntilVisible(timeout: _uiTimeout);

    final musicSwitch = $(#settingsMusicSwitch);
    await musicSwitch.waitUntilVisible(timeout: _uiTimeout);
    final wasEnabled = $.tester.widget<Switch>(musicSwitch).value;
    await musicSwitch.tap();
    await musicSwitch
        .which<Switch>((widget) => widget.value != wasEnabled)
        .waitUntilExists(timeout: _uiTimeout);

    await $('Resume').waitUntilVisible(timeout: _uiTimeout).tap();
    await $('Hold:').waitUntilVisible(timeout: _uiTimeout);
    expect($('Settings'), findsNothing);
  });
}
