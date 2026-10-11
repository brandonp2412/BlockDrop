import 'package:block_drop/l10n/app_localizations.dart';
import 'package:block_drop/screens/settings_screen.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _focusIsInside(Key key) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  if (context.widget.key == key) return true;
  var found = false;
  context.visitAncestorElements((ancestor) {
    if (ancestor.widget.key == key) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

void main() {
  testWidgets('D-pad reaches every settings section and returns to the top', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsProvider();
    await settings.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(settings: settings),
      ),
    );
    final searchFocus =
        tester.widget<EditableText>(find.byType(EditableText)).focusNode;
    searchFocus.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, searchFocus);

    final importantControls = <Key>{
      Key('settingsMusicSwitch'),
      Key('settings-on-screen-controls'),
      Key('controller-binding-moveLeft'),
      Key('reset-controller-bindings'),
      Key('settingsLanguageDropdown'),
      Key('settings-link-Support Development'),
    };
    final visitedControls = <Key>{};
    final visitedNodes = <FocusNode>{};
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    var mostScroll = 0.0;
    var reachedBottom = false;
    for (var index = 0; index < 80; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      if (FocusManager.instance.primaryFocus case final node?) {
        visitedNodes.add(node);
      }
      mostScroll = mostScroll < scrollable.position.pixels
          ? scrollable.position.pixels
          : mostScroll;
      for (final key in importantControls) {
        if (_focusIsInside(key)) visitedControls.add(key);
      }
      if (_focusIsInside(const Key('settings-link-Support Development'))) {
        reachedBottom = true;
        break;
      }
    }
    expect(reachedBottom, isTrue);
    expect(visitedNodes.length, greaterThan(28));
    expect(visitedControls, containsAll(importantControls));
    expect(mostScroll, greaterThan(400));

    var returnedToSearch = false;
    for (var index = 0; index < 80; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      if (FocusManager.instance.primaryFocus == searchFocus) {
        returnedToSearch = true;
        break;
      }
    }
    expect(returnedToSearch, isTrue);
  });
}
