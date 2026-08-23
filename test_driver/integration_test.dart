// test_driver/integration_test.dart

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      onScreenshot: (name, image, [args]) async {
        final deviceType =
            Platform.environment['BLOCKDROP_DEVICE_TYPE'] ?? 'phoneScreenshots';
        final screenshotDirectory =
            'fastlane/metadata/android/en-US/images/$deviceType';
        Directory(screenshotDirectory).createSync(recursive: true);
        await File('$screenshotDirectory/$name.png').writeAsBytes(image);

        stdout.writeln('Screenshots written to fastlane/ directories.');
        return true;
      },
    );
