import 'dart:convert';
import 'dart:io';

import 'package:block_drop/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _playStoreLocales = <String, String>{
  'th': 'th-TH',
  'tr': 'tr-TR',
  'vi': 'vi-VN',
  'de': 'de-DE',
  'es': 'es-ES',
  'fr': 'fr-FR',
  'pt': 'pt-BR',
  'pl': 'pl-PL',
  'it': 'it-IT',
  'bn': 'bn-BD',
  'ur': 'ur',
  'fa': 'fa',
  'nl': 'nl-NL',
  'ja': 'ja-JP',
  'ko': 'ko-KR',
  'zh-Hans': 'zh-CN',
  'zh-Hant': 'zh-TW',
  'ru': 'ru-RU',
  'uk': 'uk-UA',
  'hi': 'hi-IN',
  'ar': 'ar',
  'id': 'id-ID',
  'ms': 'ms-MY',
};

const _appStoreLocales = <String, String>{
  'th': 'th',
  'tr': 'tr',
  'vi': 'vi',
  'de': 'de-DE',
  'es': 'es-ES',
  'fr': 'fr-FR',
  'pt': 'pt-BR',
  'pl': 'pl',
  'it': 'it',
  'bn': 'bn',
  'ur': 'ur-PK',
  'nl': 'nl-NL',
  'ja': 'ja',
  'ko': 'ko',
  'zh-Hans': 'zh-Hans',
  'zh-Hant': 'zh-Hant',
  'ru': 'ru',
  'uk': 'uk',
  'hi': 'hi',
  'ar': 'ar-SA',
  'id': 'id',
  'ms': 'ms',
};

String _read(String path) => File(path).readAsStringSync().trim();

Set<String> _textFileNames(String path) => Directory(path)
    .listSync()
    .whereType<File>()
    .where((file) => file.path.endsWith('.txt'))
    .map((file) => file.uri.pathSegments.last)
    .toSet();

void main() {
  test('localized F-Droid metadata is translated', () {
    const englishDir = 'metadata/en-US';
    const localizedDirs = [
      'metadata/th-TH',
      'metadata/tr-TR',
      'metadata/vi-VN',
      'metadata/de-DE',
      'metadata/fr-FR',
      'metadata/pt-BR',
      'metadata/pl-PL',
      'metadata/it-IT',
      'metadata/bn-BD',
      'metadata/ur-PK',
      'metadata/fa',
      'metadata/nl-NL',
      'metadata/ja-JP',
      'metadata/ko-KR',
      'metadata/zh-CN',
      'metadata/zh-TW',
      'metadata/ru-RU',
      'metadata/uk-UA',
      'metadata/hi-IN',
      'metadata/ar-SA',
      'metadata/id-ID',
      'metadata/ms-MY',
    ];

    for (final localizedDir in localizedDirs) {
      expect(Directory(localizedDir).existsSync(), isTrue);
      for (final filename in const [
        'short_description.txt',
        'full_description.txt',
        'changelogs/1.txt',
      ]) {
        final english = _read('$englishDir/$filename');
        final localized = _read('$localizedDir/$filename');
        expect(localized, isNotEmpty);
        expect(localized, isNot(equals(english)));
      }
    }
  });

  final supportedLanguages = AppLocalizations.supportedLocales
      .where((locale) => locale.languageCode != 'en')
      .map(
        (locale) => locale.languageCode == 'zh'
            ? 'zh-${locale.scriptCode}'
            : locale.languageCode,
      )
      .toSet();

  test('store locale mappings cover every translated app locale', () {
    expect(_playStoreLocales.keys.toSet(), supportedLanguages);

    const appStoreUnsupportedLocales = {'fa'};
    expect(
      _appStoreLocales.keys.toSet(),
      supportedLanguages.difference(appStoreUnsupportedLocales),
    );
  });

  test('Play Store metadata is localized for every translated locale', () {
    const englishDir = 'fastlane/metadata/android/en-US';
    final expectedFiles = _textFileNames(englishDir);

    for (final locale in _playStoreLocales.values) {
      final localeDir = 'fastlane/metadata/android/$locale';
      expect(
        Directory(localeDir).existsSync(),
        isTrue,
        reason: '$locale must have Play Store metadata',
      );
      expect(
        _textFileNames(localeDir),
        expectedFiles,
        reason: '$locale must mirror the English Play Store text files',
      );

      for (final filename in const [
        'title.txt',
        'short_description.txt',
        'full_description.txt',
      ]) {
        final english = _read('$englishDir/$filename');
        final localized = _read('$localeDir/$filename');
        expect(localized, isNotEmpty);
        expect(
          localized,
          isNot(equals(english)),
          reason: '$locale/$filename must be translated',
        );
      }

      expect(
        _read('$localeDir/title.txt').runes.length,
        lessThanOrEqualTo(30),
        reason: '$locale Play title must fit Google Play limits',
      );
      expect(
        _read('$localeDir/short_description.txt').runes.length,
        lessThanOrEqualTo(80),
        reason: '$locale Play short description must fit Google Play limits',
      );
      expect(
        _read('$localeDir/full_description.txt').runes.length,
        lessThanOrEqualTo(4000),
        reason: '$locale Play full description must fit Google Play limits',
      );
    }
  });

  test('App Store metadata is localized for every translated locale', () {
    const englishDir = 'fastlane/metadata/en-AU';
    final expectedFiles = _textFileNames(englishDir);

    for (final locale in _appStoreLocales.values) {
      final localeDir = 'fastlane/metadata/$locale';
      expect(
        Directory(localeDir).existsSync(),
        isTrue,
        reason: '$locale must have App Store metadata',
      );
      expect(
        _textFileNames(localeDir),
        expectedFiles,
        reason: '$locale must mirror the English App Store text files',
      );

      for (final filename in const [
        'description.txt',
        'keywords.txt',
        'release_notes.txt',
      ]) {
        final english = _read('$englishDir/$filename');
        final localized = _read('$localeDir/$filename');
        expect(localized, isNotEmpty);
        expect(
          localized,
          isNot(equals(english)),
          reason: '$locale/$filename must be translated',
        );
      }

      expect(
        _read('$localeDir/name.txt').runes.length,
        lessThanOrEqualTo(30),
        reason: '$locale App Store name must fit App Store limits',
      );
      expect(
        _read('$localeDir/subtitle.txt').runes.length,
        lessThanOrEqualTo(30),
        reason: '$locale App Store subtitle must fit App Store limits',
      );
      expect(
        utf8.encode(_read('$localeDir/keywords.txt')).length,
        lessThanOrEqualTo(100),
        reason: '$locale App Store keywords must fit App Store limits',
      );
    }
  });
}
