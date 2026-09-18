import 'package:block_drop/constants/game_constants.dart';
import 'package:block_drop/l10n/app_localizations.dart';
import 'package:block_drop/l10n/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every supported non-English locale has the same translation keys', () {
    final supportedLanguages = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .where((language) => language != 'en')
        .toSet();

    expect(appTranslations.keys.toSet(), supportedLanguages);

    final referenceKeys = appTranslations['de']!.keys.toSet();
    expect(referenceKeys, hasLength(188));

    for (final entry in appTranslations.entries) {
      expect(
        entry.value.keys.toSet(),
        referenceKeys,
        reason: '${entry.key} must have the complete translation key set',
      );
    }
  });

  test('dynamic user-facing labels have explicit translations', () {
    final labels = <String>{
      'Player',
      'Unknown',
      'Someone',
      'Opponent',
      ...GameConstants.lineClearLabels.where((label) => label.isNotEmpty),
      ...GameConstants.tSpinLabels,
    };

    for (final locale in appTranslations.entries) {
      expect(
        locale.value.keys,
        containsAll(labels),
        reason: '${locale.key} must translate every dynamic user-facing label',
      );
    }
  });

  test('translated values preserve named placeholders', () {
    final placeholderPattern = RegExp(r'\{([a-zA-Z][a-zA-Z0-9_]*)\}');

    Set<String> placeholders(String value) => placeholderPattern
        .allMatches(value)
        .map((match) => match.group(1)!)
        .toSet();

    for (final locale in appTranslations.entries) {
      for (final translation in locale.value.entries) {
        expect(
          placeholders(translation.value),
          placeholders(translation.key),
          reason:
              '${locale.key} translation for "${translation.key}" changed placeholders',
        );
      }
    }
  });

  test('runtime multiplayer messages are localized', () {
    const german = AppLocalizations(Locale('de'));

    expect(
      german.runtimeText(
        'Could not connect to Alex. Make sure they have Block Drop open.',
      ),
      'Verbindung zu Alex konnte nicht hergestellt werden. '
      'Stelle sicher, dass Block Drop geöffnet ist.',
    );
    expect(
      german.runtimeText(
        "Check that Block Drop is allowed in Windows Defender Firewall on Alex's device.",
      ),
      'Stelle sicher, dass Block Drop in der Windows Defender Firewall '
      'auf dem Gerät von Alex zugelassen ist.',
    );
    expect(
      german.runtimeText('Alex disconnected'),
      'Alex hat die Verbindung getrennt',
    );
  });

  test('dynamic controller button labels use the locale template', () {
    const german = AppLocalizations(Locale('de'));
    const japanese = AppLocalizations(Locale('ja'));

    expect(german.text('Button 17'), 'Taste 17');
    expect(japanese.text('Button 17'), '17ボタン');
  });
}
