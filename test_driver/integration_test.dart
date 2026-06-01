// test_driver/integration_test.dart

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      onScreenshot: (name, image, [args]) async {
        const phoneDir =
            'fastlane/metadata/android/en-US/images/phoneScreenshots';
        Directory(phoneDir).createSync(recursive: true);
        await File(
                'fastlane/metadata/android/en-US/images/phoneScreenshots/$name.png')
            .writeAsBytes(image);

        stdout.writeln('Screenshots written to fastlane/ directories.');
        return true;
      },
    );
