// test_driver/integration_test.dart
//
// Host-side driver for the screenshot integration test.
// Runs on the developer's machine via `flutter drive`.
// Receives screenshot PNG bytes from the on-device test,
// decodes them, and writes them into the fastlane directory structure.

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (Map<String, dynamic>? data) async {
    if (data == null || !data.containsKey('screenshots')) return;

    // Output directories (all relative to the repo root, which is the CWD
    // when flutter drive is invoked from the project root).
    const androidDir = 'fastlane/screenshots/android';
    const phoneDir = 'fastlane/metadata/android/en-US/images/phoneScreenshots';
    const iphone67Dir =
        'fastlane/metadata/ios/en-US/images/iphone67Screenshots';
    const iphone65Dir =
        'fastlane/metadata/ios/en-US/images/iphone65Screenshots';

    for (final dir in [androidDir, phoneDir, iphone67Dir, iphone65Dir]) {
      Directory(dir).createSync(recursive: true);
    }

    final screenshots = data['screenshots'] as Map<String, dynamic>;

    // Keys are "<index>:<name>", e.g. "1:light_classic"
    for (final entry in screenshots.entries) {
      final parts = entry.key.split(':');
      final index = parts[0];
      final name = parts[1];
      final bytes = base64Decode(entry.value as String);

      await File('$androidDir/$name.png').writeAsBytes(bytes);
      await File('$phoneDir/$index.png').writeAsBytes(bytes);
      await File('$iphone67Dir/$index.png').writeAsBytes(bytes);
      await File('$iphone65Dir/$index.png').writeAsBytes(bytes);

      stdout.writeln('  Saved $name.png (index $index)');
    }

    stdout.writeln('Screenshots written to fastlane/ directories.');
  },
);
