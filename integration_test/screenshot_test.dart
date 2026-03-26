// integration_test/screenshot_test.dart
//
// Generates screenshots for every theme × style combination.
// Run via flutter drive (see test_driver/integration_test.dart):
//
//   flutter drive \
//     --no-enable-impeller \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshot_test.dart \
//     -d emulator-5554
//
// Each PNG is written directly to the device's app-specific internal storage
// (/data/data/com.blockdrop.game/files/screenshots/) as it is captured.
// The host driver retrieves them via `adb pull` (or `adb shell run-as` fallback).
//
// NOTE: This test deliberately avoids tester.pump() for ALL waits.
// In LiveTestWidgetsFlutterBinding, pump() calls scheduleWarmUpFrame() which
// can deadlock when the Flutter scheduler is between vsync phases.
// Instead we use Future.delayed() (real-time wall-clock waits) and call the
// integration_test platform channel directly for screenshot capture.

import 'dart:io';

import 'package:block_drop/main.dart' as app;
import 'package:block_drop/screens/tetris_game_screen.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Themes to capture — skip 'system' because its appearance is platform-dependent.
const _themes = [
  AppThemeMode.light,
  AppThemeMode.dark,
  AppThemeMode.black,
];

// All five visual styles.
const _styles = AppStyle.values;

// Internal app storage — always writable by the app, no permissions needed.
// On the emulator `adb root` (or `adb shell run-as`) gives the host driver
// pull access.
const _screenshotDir = '/data/data/com.blockdrop.game/files/screenshots';

// Method channel used internally by the integration_test package on Android.
// We invoke it directly to bypass the pump() call inside
// IntegrationTestWidgetsFlutterBinding.takeScreenshot().
// Must use the default StandardMethodCodec — the Android plugin registers its
// handler with StandardMethodCodec; JSONMethodCodec causes MissingPluginException.
const _integrationChannel = MethodChannel(
  'plugins.flutter.io/integration_test',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Generate screenshots for all theme × style combinations',
    (tester) async {
      // Clean up screenshots from previous runs.
      final dir = Directory(_screenshotDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);

      // Boot the real app.
      app.main();

      // ONE pump immediately after app.main() — called before the game's
      // Timer.periodic has had a chance to fire.  runApp() schedules its own
      // warm-up frame (sets _warmUpFrame = true); our pump() sees that flag,
      // skips scheduleWarmUpFrame(), and simply waits for the already-
      // scheduled warm-up frame to complete.  This populates the element tree
      // without the deadlock that occurs when pump() races the live 60-fps
      // vsync loop.
      await tester.pump();

      // From this point every wait uses Future.delayed (real-time wall-clock).
      // We never call tester.pump() again because subsequent calls conflict
      // with the running game loop's Timer.periodic → setState() → vsync cycle.

      // Grab the SettingsProvider from the now-populated element tree.
      final settings = tester
          .widget<TetrisGameScreen>(find.byType(TetrisGameScreen))
          .settings;

      // Silence audio before the screenshot loop — style changes trigger audio
      // lifecycle events (MediaPlayer reset/prepare) that can crash the emulator
      // if fired rapidly in succession.
      await settings.setMusicEnabled(false);
      await settings.setSfxEnabled(false);

      // Wait for audio initialisation to settle (8 SFX setSource() calls).
      await Future.delayed(const Duration(seconds: 3));

      int index = 1;

      for (final theme in _themes) {
        for (final style in _styles) {
          if (theme == AppThemeMode.light && style == AppStyle.neon) continue;
          if (theme == AppThemeMode.system && style == AppStyle.neon) continue;

          // Apply theme + style — the live vsync loop will rebuild naturally.
          await settings.setThemeMode(theme);
          await settings.setStyle(style);

          // Wait for the live render loop to flush the theme change.
          // At 60 fps this takes ~16 ms; we give 1 s of headroom.
          await Future.delayed(const Duration(seconds: 1));

          final name = '${theme.name}_${style.name}';

          // captureScreenshot requires the Flutter surface to be in image mode.
          // Convert → capture → revert mirrors what binding.takeScreenshot() does
          // internally, but without the pump() call in between.
          await _integrationChannel
              .invokeMethod<void>('convertFlutterSurfaceToImage');

          // Give the surface conversion a frame to settle.
          await Future.delayed(const Duration(milliseconds: 500));

          final Uint8List? bytes =
              await _integrationChannel.invokeMethod<Uint8List>(
            'captureScreenshot',
            <String, Object?>{'name': name},
          );

          await _integrationChannel.invokeMethod<void>('revertFlutterImage');

          if (bytes != null) {
            await File('$_screenshotDir/$index:$name.png').writeAsBytes(bytes);
          }

          // ignore: avoid_print
          print('  [$index/14] Captured $name');
          index++;
        }
      }

      // Signal completion; the host driver will adb-pull the directory.
      IntegrationTestWidgetsFlutterBinding.instance.reportData = {
        'screenshotDir': _screenshotDir,
        'count': index - 1,
      };
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
