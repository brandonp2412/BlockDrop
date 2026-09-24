import 'dart:convert';
import 'dart:io';

import 'package:block_drop/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _playStoreLocales = <String, String>{
  'de': 'de-DE',
  'es': 'es-ES',
  'fr': 'fr-FR',
  'pt': 'pt-BR',
  'ja': 'ja-JP',
  'ko': 'ko-KR',
  'zh': 'zh-CN',
  'ru': 'ru-RU',
  'hi': 'hi-IN',
};

const _appStoreLocales = <String, String>{
  'de': 'de-DE',
  'es': 'es-ES',
  'fr': 'fr-FR',
  'pt': 'pt-BR',
  'ja': 'ja',
  'ko': 'ko',
  'zh': 'zh-Hans',
  'ru': 'ru',
  'hi': 'hi',
};

String _read(String path) => File(path).readAsStringSync().trim();

Set<String> _textFileNames(String path) => Directory(path)
    .listSync()
    .whereType<File>()
    .where((file) => file.path.endsWith('.txt'))
    .map((file) => file.uri.pathSegments.last)
    .toSet();

void main() {
  final supportedLanguages = AppLocalizations.supportedLocales
      .map((locale) => locale.languageCode)
      .where((language) => language != 'en')
      .toSet();

  test('store locale mappings cover every translated app locale', () {
    expect(_playStoreLocales.keys.toSet(), supportedLanguages);
    expect(_appStoreLocales.keys.toSet(), supportedLanguages);
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
