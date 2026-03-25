// integration_test/screenshot_test.dart
//
// Generates screenshots for every theme × style combination.
// Run via flutter drive (see test_driver/integration_test.dart):
//
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshot_test.dart \
//     -d emulator-5554
//
// The driver on the host machine receives the PNG bytes and writes them into
// the fastlane directory structure.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:block_drop/main.dart' as app;
import 'package:block_drop/screens/tetris_game_screen.dart';
import 'package:block_drop/settings/settings_provider.dart';

// Themes to capture — skip 'system' because its appearance is platform-dependent.
const _themes = [
  AppThemeMode.light,
  AppThemeMode.dark,
  AppThemeMode.black,
];

// All five visual styles.
const _styles = AppStyle.values;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Generate screenshots for all theme × style combinations',
    (tester) async {
      // Boot the real app.
      app.main();

      // Give the app time to initialise audio, load SharedPreferences, and
      // render the first frame.
      await tester.pump(const Duration(seconds: 3));

      // Grab the SettingsProvider from the live widget tree.
      final settings = tester
          .widget<TetrisGameScreen>(find.byType(TetrisGameScreen))
          .settings;

      // Required on Android before any call to takeScreenshot().
      // Converts the OpenGL/Vulkan surface to a raster image that can be read.
      await binding.convertFlutterSurfaceToImage();

      // Collect screenshots as base64 strings keyed by "<index>:<name>".
      // The driver on the host decodes these and writes them to disk.
      final screenshotData = <String, String>{};
      int index = 1;

      for (final theme in _themes) {
        for (final style in _styles) {
          // Apply theme + style and let Flutter rebuild.
          await settings.setThemeMode(theme);
          await settings.setStyle(style);

          // Pump twice: once for ChangeNotifier, once for layout/paint.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));

          final name = '${theme.name}_${style.name}';

          // Capture the current screen (works on Android/iOS).
          final bytes = Uint8List.fromList(await binding.takeScreenshot(name));

          // Encode as base64 so it survives JSON transport to the host driver.
          screenshotData['$index:$name'] = base64Encode(bytes);

          // ignore: avoid_print
          print('  [$index/15] Captured $name');
          index++;
        }
      }

      // Report all screenshot data back to the host via the drive protocol.
      binding.reportData = {'screenshots': screenshotData};
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
