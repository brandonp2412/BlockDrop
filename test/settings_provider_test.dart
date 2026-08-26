import 'package:block_drop/settings/settings_provider.dart';
import 'package:block_drop/game/gameplay_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      expect(settings.enableHold, true);
      expect(settings.showOnScreenControls, false);
      expect(settings.fullscreenBoard, false);
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

    test(
      'updateHighScore does not update when score equals current high score',
      () async {
        final settings = SettingsProvider();

        await settings.updateHighScore(300);
        expect(settings.highScore, 300);

        await settings.updateHighScore(
          300,
        ); // equal — should not trigger notify
        expect(settings.highScore, 300);
      },
    );

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

    test(
      'flutterThemeMode maps each AppThemeMode to the correct ThemeMode',
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
      },
    );

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

    test('setEnableHold updates the current hold preference', () async {
      final settings = SettingsProvider();

      expect(settings.enableHold, true);

      await settings.setEnableHold(false);
      expect(settings.enableHold, false);

      await settings.setEnableHold(true);
      expect(settings.enableHold, true);
    });

    test('persists the on-screen controls preference', () async {
      final settings = SettingsProvider();

      await settings.setShowOnScreenControls(true);
      expect(settings.showOnScreenControls, true);

      final reloadedSettings = SettingsProvider();
      await reloadedSettings.load();
      expect(reloadedSettings.showOnScreenControls, true);
    });

    test('fullscreen board setting persists across providers', () async {
      final settings = SettingsProvider();

      await settings.setFullscreenBoard(true);
      expect(settings.fullscreenBoard, true);

      final reloadedSettings = SettingsProvider();
      await reloadedSettings.load();
      expect(reloadedSettings.fullscreenBoard, true);
    });

    test('persists and loads all gameplay settings', () async {
      final settings = SettingsProvider();
      const rules = GameplaySettings(
        initialDropSpeed: 1400,
        speedIncrement: 30,
        maximumLevel: 0,
        linesPerLevel: 7,
        softDropEnabled: false,
        holdEnabled: false,
        holdInteractionMode: HoldInteractionMode.panelOnly,
      );

      await settings.setGameplaySettings(rules);
      final reloaded = SettingsProvider();
      await reloaded.load();

      expect(reloaded.gameplay.initialDropSpeed, 1400);
      expect(reloaded.gameplay.speedIncrement, 30);
      expect(reloaded.gameplay.maximumLevel, 0);
      expect(reloaded.gameplay.linesPerLevel, 7);
      expect(reloaded.gameplay.softDropEnabled, false);
      expect(reloaded.enableHold, false);
      expect(
        reloaded.gameplay.holdInteractionMode,
        HoldInteractionMode.panelOnly,
      );
    });

    test('clamps invalid persisted gameplay values', () async {
      SharedPreferences.setMockInitialValues({
        'initial_drop_speed': -1,
        'speed_increment': 999,
        'maximum_level': 999,
        'lines_per_level': 0,
      });
      final settings = SettingsProvider();

      await settings.load();

      expect(settings.gameplay.initialDropSpeed, 200);
      expect(settings.gameplay.speedIncrement, 200);
      expect(settings.gameplay.maximumLevel, 100);
      expect(settings.gameplay.linesPerLevel, 1);
    });
  });
}
