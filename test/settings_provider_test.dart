import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:block_drop/settings/settings_provider.dart';

void main() {
  group('SettingsProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts with correct default values', () {
      final settings = SettingsProvider();

      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.style, AppStyle.classic);
      expect(settings.musicEnabled, false);
      expect(settings.sfxEnabled, false);
      expect(settings.highScore, 0);
    });

    test('updateHighScore only updates when the new score is higher', () async {
      final settings = SettingsProvider();

      await settings.updateHighScore(500);
      expect(settings.highScore, 500);

      await settings.updateHighScore(200); // lower — should be ignored
      expect(settings.highScore, 500);

      await settings.updateHighScore(1000); // higher — should update
      expect(settings.highScore, 1000);
    });

    test('updateHighScore does not update when score equals current high score',
        () async {
      final settings = SettingsProvider();

      await settings.updateHighScore(300);
      expect(settings.highScore, 300);

      await settings.updateHighScore(300); // equal — should not trigger notify
      expect(settings.highScore, 300);
    });

    test('isBlackMode is true only for AppThemeMode.black', () async {
      final settings = SettingsProvider();

      expect(settings.isBlackMode, false); // default is system

      await settings.setThemeMode(AppThemeMode.black);
      expect(settings.isBlackMode, true);

      await settings.setThemeMode(AppThemeMode.dark);
      expect(settings.isBlackMode, false);

      await settings.setThemeMode(AppThemeMode.light);
      expect(settings.isBlackMode, false);

      await settings.setThemeMode(AppThemeMode.system);
      expect(settings.isBlackMode, false);
    });

    test('flutterThemeMode maps each AppThemeMode to the correct ThemeMode',
        () async {
      final settings = SettingsProvider();

      await settings.setThemeMode(AppThemeMode.system);
      expect(settings.flutterThemeMode, ThemeMode.system);

      await settings.setThemeMode(AppThemeMode.light);
      expect(settings.flutterThemeMode, ThemeMode.light);

      await settings.setThemeMode(AppThemeMode.dark);
      expect(settings.flutterThemeMode, ThemeMode.dark);

      // Black AMOLED mode piggybacks on dark theme
      await settings.setThemeMode(AppThemeMode.black);
      expect(settings.flutterThemeMode, ThemeMode.dark);
    });

    test('setMusicEnabled and setSfxEnabled update in-memory state', () async {
      final settings = SettingsProvider();

      expect(settings.musicEnabled, false);
      expect(settings.sfxEnabled, false);

      await settings.setMusicEnabled(true);
      expect(settings.musicEnabled, true);

      await settings.setSfxEnabled(true);
      expect(settings.sfxEnabled, true);

      await settings.setMusicEnabled(false);
      expect(settings.musicEnabled, false);
    });

    test('setStyle updates the current style', () async {
      final settings = SettingsProvider();

      expect(settings.style, AppStyle.classic);

      await settings.setStyle(AppStyle.neon);
      expect(settings.style, AppStyle.neon);

      await settings.setStyle(AppStyle.retro);
      expect(settings.style, AppStyle.retro);
    });
  });
}
