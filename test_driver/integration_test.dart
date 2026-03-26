// test_driver/integration_test.dart
//
// Host-side driver for the screenshot integration test.
// Runs on the developer's machine via `flutter drive`.
//
// The on-device test writes PNGs to the device's app-specific internal
// storage.  This driver pulls them via `adb pull` and distributes them
// into the standard fastlane metadata directory structure.

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (Map<String, dynamic>? data) async {
    if (data == null || !data.containsKey('screenshotDir')) return;

    final remoteDir = data['screenshotDir'] as String;

    // Standard fastlane metadata directories.
    // Named PNGs (e.g. light_classic.png) work fine with `supply` and `deliver`;
    // both tools upload all PNGs found in these directories.
    const phoneDir = 'fastlane/metadata/android/en-US/images/phoneScreenshots';
    const iphone67Dir =
        'fastlane/metadata/ios/en-US/images/iphone67Screenshots';
    const iphone65Dir =
        'fastlane/metadata/ios/en-US/images/iphone65Screenshots';

    for (final dir in [phoneDir, iphone67Dir, iphone65Dir]) {
      Directory(dir).createSync(recursive: true);
    }

    // Pull all screenshots from the device into a temporary local directory.
    final tempDir = Directory(
      '${Directory.systemTemp.path}/block_drop_screenshots',
    );
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    // Resolve device ID: prefer env var set by the screenshot script, then
    // fall back to the first connected emulator reported by `adb devices`.
    String? deviceId = Platform.environment['ANDROID_DEVICE_ID'];
    if (deviceId == null || deviceId.isEmpty) {
      final devResult = await Process.run('adb', ['devices']);
      final lines = (devResult.stdout as String).split('\n');
      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2 && parts[1] == 'device') {
          deviceId = parts[0];
          break;
        }
      }
    }

    final adbBase = <String>['adb'];
    if (deviceId != null && deviceId.isNotEmpty) {
      adbBase.addAll(['-s', deviceId]);
    }

    // Attempt direct adb pull (works when adb root is available).
    // If it fails (e.g. google_apis image where adbd can't run as root), fall
    // back to `adb shell run-as <pkg> cp` to copy files to /sdcard first.
    stdout.writeln('  Pulling screenshots from device ($deviceId)...');
    var pullResult = await Process.run(
      adbBase[0],
      [...adbBase.sublist(1), 'pull', remoteDir, tempDir.path],
    );

    if (pullResult.exitCode != 0) {
      stdout.writeln(
        '  Direct pull failed (${pullResult.stderr.toString().trim()}) — trying run-as fallback...',
      );
      // Stage on /sdcard using the same dir name so the pull logic below works.
      final stagingDir = '/sdcard/${remoteDir.split('/').last}';
      // Copy from internal storage to world-readable sdcard via run-as.
      final cpResult = await Process.run(adbBase[0], [
        ...adbBase.sublist(1),
        'shell',
        'run-as',
        'com.blockdrop.game',
        'sh',
        '-c',
        'cp -r $remoteDir $stagingDir',
      ]);
      if (cpResult.exitCode != 0) {
        stderr.writeln(
          'run-as cp failed: ${cpResult.stderr}\nCould not retrieve screenshots from device.',
        );
        return;
      }
      // Now pull from sdcard.
      pullResult = await Process.run(
        adbBase[0],
        [...adbBase.sublist(1), 'pull', stagingDir, tempDir.path],
      );
      // Clean up the staging dir.
      await Process.run(adbBase[0], [
        ...adbBase.sublist(1),
        'shell',
        'rm',
        '-rf',
        stagingDir,
      ]);
      if (pullResult.exitCode != 0) {
        stderr.writeln('adb pull (sdcard fallback) failed: ${pullResult.stderr}');
        return;
      }
    }

    // `adb pull <remote_dir> <local_dir>` creates a subdirectory named after
    // the last path segment of remote_dir inside local_dir.
    final remoteDirName = remoteDir.split('/').last;
    final pulledDir = Directory('${tempDir.path}/$remoteDirName');
    final sourceDir = pulledDir.existsSync() ? pulledDir : tempDir;

    // Process files: names are "<index>:<theme>_<style>.png"
    final files =
        sourceDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.png'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final filename = file.uri.pathSegments.last; // e.g. "1:light_classic.png"
      if (!filename.contains(':')) continue;

      final colonIdx = filename.indexOf(':');
      final name = filename.substring(colonIdx + 1, filename.length - 4);

      final bytes = await file.readAsBytes();
      await File('$phoneDir/$name.png').writeAsBytes(bytes);
      await File('$iphone67Dir/$name.png').writeAsBytes(bytes);
      await File('$iphone65Dir/$name.png').writeAsBytes(bytes);

      stdout.writeln('  Saved $name.png');
    }

    stdout.writeln('Screenshots written to fastlane/metadata/ directories.');
    tempDir.deleteSync(recursive: true);
  },
);
