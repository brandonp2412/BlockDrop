import 'package:block_drop/main.dart' as app;
import 'package:block_drop/settings/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _captures = [
  (theme: AppThemeMode.light, style: AppStyle.classic),
  (theme: AppThemeMode.light, style: AppStyle.modern),
  (theme: AppThemeMode.light, style: AppStyle.bubbles),
  (theme: AppThemeMode.light, style: AppStyle.retro),
  (theme: AppThemeMode.dark, style: AppStyle.classic),
  (theme: AppThemeMode.dark, style: AppStyle.neon),
  (theme: AppThemeMode.black, style: AppStyle.modern),
  (theme: AppThemeMode.black, style: AppStyle.retro),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Generate screenshots for all theme × style combinations',
    (tester) async {
      final settings = SettingsProvider(isTelevision: () async => false);
      await settings.load();
      await tester.pumpWidget(app.BlockDropApp(settings: settings));
      await tester.pump(const Duration(seconds: 3));

      // Required on Android before any call to takeScreenshot().
      // Converts the OpenGL/Vulkan surface to a raster image that can be read.
      await binding.convertFlutterSurfaceToImage();

      for (var index = 0; index < _captures.length; index++) {
        final capture = _captures[index];

        await settings.setThemeMode(capture.theme);
        await settings.setStyle(capture.style);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        final ordinal = index + 1;
        final label = '${capture.theme.name}_${capture.style.name}';
        final name = '${ordinal}_en-US';
        await binding.takeScreenshot(name);
        print('[$ordinal/${_captures.length}] Captured $label as $name');
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
