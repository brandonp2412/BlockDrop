import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:block_drop/audio/audio_service.dart';
import 'package:block_drop/main.dart';
import 'package:block_drop/screens/block_drop_game_screen.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const path = String.fromEnvironment('AUDIO_TEST_FILE');

  testWidgets(
      'native player decodes imported music and recovers from bad files',
      (tester) async {
    expect(File(path).existsSync(), isTrue);
    final player = AudioPlayer();
    final service = AudioService(
      musicEnabled: false,
      musicPlayer: player,
    );
    final directory = await Directory.systemTemp.createTemp('blockdrop_audio_');
    addTearDown(() async {
      await service.dispose();
      await directory.delete(recursive: true);
    });

    await service.init();
    await service.setCustomSources(musicPath: path, sfxPaths: const {});
    await service.setMusicEnabled(true);
    await Future<void>.delayed(const Duration(seconds: 2));
    final firstPosition = await player.getCurrentPosition();
    expect(player.state, PlayerState.playing);
    expect(firstPosition, isNotNull);
    expect(firstPosition!.inMilliseconds, greaterThan(500));
    await Future<void>.delayed(const Duration(seconds: 1));
    final secondPosition = await player.getCurrentPosition();
    expect(secondPosition, greaterThan(firstPosition));
    // ignore: avoid_print
    print('Native music playback advanced: $firstPosition -> $secondPosition');

    await service.pauseMusic();
    final invalid = File('${directory.path}/invalid.mp3');
    await invalid.writeAsString('This is not an audio file.');
    await service.setCustomSources(
      musicPath: invalid.path,
      sfxPaths: const {},
    );
    await service.setMusicEnabled(true);
    expect(player.state, isNot(PlayerState.playing));

    await service.setCustomSources(musicPath: path, sfxPaths: const {});
    await service.setMusicEnabled(true);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(player.state, PlayerState.playing);
    expect(
        (await player.getCurrentPosition())!.inMilliseconds, greaterThan(300));
    await service.stopMusic();
  }, skip: path.isEmpty);

  testWidgets('game sends selected music to the Linux audio server',
      (tester) async {
    final settings = SettingsProvider();
    await settings.load();
    final previousPath = settings.customMusicPath;
    final previousEnabled = settings.musicEnabled;
    await settings.setCustomMusicPath(path);
    try {
      await tester.pumpWidget(BlockDropApp(settings: settings));
      await tester.pump(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(find.byType(BlockDropGameScreen), findsOneWidget);

      final result = await Process.run(
        'pactl',
        ['--format=json', 'list', 'sink-inputs'],
      );
      expect(result.exitCode, 0);
      final streams = (jsonDecode(result.stdout as String) as List)
          .cast<Map<String, dynamic>>()
          .where((stream) =>
              stream['properties']['application.process.id'] == '$pid' &&
              stream['corked'] == false &&
              stream['mute'] == false)
          .toList();
      expect(streams, isNotEmpty,
          reason: 'The running game must have an active audio output stream.');
      // ignore: avoid_print
      print(
          'Game audio output active: ${streams.first['properties']['media.name']}');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await settings.setCustomMusicPath(previousPath);
      await settings.setMusicEnabled(previousEnabled);
      settings.dispose();
    }
  }, skip: path.isEmpty || !const bool.fromEnvironment('AUDIO_TEST_PULSE'));
}
