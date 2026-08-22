// test_driver/integration_test.dart

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      onScreenshot: (name, image, [args]) async {
        final deviceType = Platform.environment['BLOCKDROP_DEVICE_TYPE'];
        if (deviceType == null || deviceType.isEmpty) {
          throw StateError('BLOCKDROP_DEVICE_TYPE must be set.');
        }

        final outputDirectory = deviceType == 'desktop'
            ? 'fastlane/screenshots/en-US'
            : 'fastlane/metadata/android/en-US/images/$deviceType';
        await Directory(outputDirectory).create(recursive: true);
        await File('$outputDirectory/$name.png').writeAsBytes(image);

        stdout.writeln('Wrote $outputDirectory/$name.png');
        return true;
      },
      writeResponseOnFailure: true,
    );
