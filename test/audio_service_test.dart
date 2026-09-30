import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:block_drop/audio/audio_service.dart';
import 'package:block_drop/audio/sfx_pack.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

class FakeSource extends Fake implements Source {}

class FakeAudioContext extends Fake implements AudioContext {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSource());
    registerFallbackValue(ReleaseMode.loop);
    registerFallbackValue(PlayerMode.mediaPlayer);
    registerFallbackValue(FakeAudioContext());
  });

  /// Returns a stub SFX player that accepts the calls made in AudioService.init().
  MockAudioPlayer makeSfxPlayer() {
    final mock = MockAudioPlayer();
    when(() => mock.setPlayerMode(any())).thenAnswer((_) async {});
    when(() => mock.setAudioContext(any())).thenAnswer((_) async {});
    when(() => mock.setVolume(any())).thenAnswer((_) async {});
    when(() => mock.setSource(any())).thenAnswer((_) async {});
    when(() => mock.play(any())).thenAnswer((_) async {});
    when(() => mock.dispose()).thenAnswer((_) async {});
    return mock;
  }

  /// Sets up a mock music player whose [play()] emits the normal
  /// stopped→playing state transitions, and whose [resume()] emits playing.
  /// Returns the player and the state stream controller.
  (MockAudioPlayer, StreamController<PlayerState>) makeMusicPlayer() {
    final stateController = StreamController<PlayerState>.broadcast();
    final mock = MockAudioPlayer();

    when(() => mock.onPlayerStateChanged)
        .thenAnswer((_) => stateController.stream);
    when(() => mock.setPlayerMode(any())).thenAnswer((_) async {});
    when(() => mock.setReleaseMode(any())).thenAnswer((_) async {});
    when(() => mock.setAudioContext(any())).thenAnswer((_) async {});
    when(() => mock.setVolume(any())).thenAnswer((_) async {});
    when(() => mock.state).thenReturn(PlayerState.stopped);
    when(() => mock.play(any())).thenAnswer((_) async {
      stateController.add(PlayerState.stopped);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      stateController.add(PlayerState.playing);
    });
    when(() => mock.resume()).thenAnswer((_) async {
      stateController.add(PlayerState.playing);
    });
    when(() => mock.pause()).thenAnswer((_) async {
      stateController.add(PlayerState.paused);
    });
    when(() => mock.stop()).thenAnswer((_) async {
      stateController.add(PlayerState.stopped);
    });
    when(() => mock.dispose()).thenAnswer((_) async {});

    return (mock, stateController);
  }

  group('AudioService — musicEnabled flag', () {
    test(
      'startMusic does not call play() when musicEnabled is false',
      () async {
        final (mockMusic, stateController) = makeMusicPlayer();

        final service = AudioService(
          musicEnabled: false,
          musicPlayer: mockMusic,
          sfxPlayerFactory: makeSfxPlayer,
        );
        await service.init();
        await service.startMusic();

        verifyNever(() => mockMusic.play(any()));

        await stateController.close();
      },
    );

    test('startMusic calls play() when musicEnabled is true', () async {
      final (mockMusic, stateController) = makeMusicPlayer();

      final service = AudioService(
        musicEnabled: true,
        musicPlayer: mockMusic,
        sfxPlayerFactory: makeSfxPlayer,
      );
      await service.init();
      await service.startMusic();

      verify(() => mockMusic.play(any())).called(1);

      await stateController.close();
    });

    test('a pause during initialization cancels pending playback', () async {
      final (mockMusic, stateController) = makeMusicPlayer();
      final initializationGate = Completer<void>();
      when(() => mockMusic.setPlayerMode(any()))
          .thenAnswer((_) => initializationGate.future);

      final service = AudioService(
        musicEnabled: true,
        musicPlayer: mockMusic,
        sfxPlayerFactory: makeSfxPlayer,
      );

      final start = service.startMusic();
      final pause = service.pauseMusic();
      initializationGate.complete();
      await Future.wait([start, pause]);

      verifyNever(() => mockMusic.play(any()));
      verify(() => mockMusic.pause()).called(1);
      await stateController.close();
    });

    test('concurrent start requests only start the player once', () async {
      final (mockMusic, stateController) = makeMusicPlayer();
      final service = AudioService(
        musicEnabled: true,
        musicPlayer: mockMusic,
        sfxPlayerFactory: makeSfxPlayer,
      );

      await Future.wait([service.startMusic(), service.startMusic()]);

      verify(() => mockMusic.play(any())).called(1);
      await stateController.close();
    });

    test('music starts without waiting for sound effects to preload', () async {
      final (mockMusic, stateController) = makeMusicPlayer();
      final mockSfx = makeSfxPlayer();
      final sfxInitializationGate = Completer<void>();
      when(() => mockSfx.setSource(any()))
          .thenAnswer((_) => sfxInitializationGate.future);
      final service = AudioService(
        musicEnabled: true,
        musicPlayer: mockMusic,
        sfxPlayerFactory: () => mockSfx,
      );

      final initialization = service.init();
      await service.startMusic().timeout(const Duration(seconds: 1));

      verify(() => mockMusic.play(any())).called(1);
      sfxInitializationGate.complete();
      await initialization;
      await stateController.close();
    });
  });

  test('initializes sound effects with the softened volume mix', () async {
    final (mockMusic, stateController) = makeMusicPlayer();
    final sfxPlayers = <MockAudioPlayer>[];
    final service = AudioService(
      musicPlayer: mockMusic,
      sfxPlayerFactory: () {
        final player = makeSfxPlayer();
        sfxPlayers.add(player);
        return player;
      },
    );

    await service.init();

    const expectedVolumes = [0.26, 0.34, 0.42, 0.5, 0.62, 0.3, 0.32, 0.38];
    for (var index = 0; index < sfxPlayers.length; index++) {
      verify(() => sfxPlayers[index].setVolume(expectedVolumes[index]))
          .called(1);
    }

    await service.dispose();
    await stateController.close();
  });

  test('bundled sound source uses the requested pack prefix', () {
    final source =
        AudioService.bundledSfxSource(SoundEffectPack.glass, 'clear');

    expect(source, isA<AssetSource>());
    expect((source as AssetSource).path, startsWith('audio/sfx/glass_clear.'));
  });

  test('Heavy clear sound escalates with consecutive clear streak', () {
    const expected = <SoundEffectPack>[
      SoundEffectPack.heavy,
      SoundEffectPack.metal,
      SoundEffectPack.power,
      SoundEffectPack.laser,
      SoundEffectPack.crystal,
      SoundEffectPack.phaser,
      SoundEffectPack.phaser,
    ];

    for (var streak = 1; streak <= expected.length; streak++) {
      expect(
        AudioService.clearPackForStreak(SoundEffectPack.heavy, streak),
        expected[streak - 1],
      );
    }
  });

  test('non-Heavy clear variants do not change with streak', () {
    for (final streak in [1, 2, 4, 10]) {
      expect(
        AudioService.clearPackForStreak(SoundEffectPack.glass, streak),
        SoundEffectPack.glass,
      );
    }
  });

  test(
    'changing only the clear variant reloads SFX without restarting music',
    () async {
      final (mockMusic, stateController) = makeMusicPlayer();
      final sfxPlayers = <MockAudioPlayer>[];
      final service = AudioService(
        musicEnabled: true,
        musicPlayer: mockMusic,
        sfxPlayerFactory: () {
          final player = makeSfxPlayer();
          sfxPlayers.add(player);
          return player;
        },
      );

      await service.init();
      for (final player in sfxPlayers) {
        clearInteractions(player);
      }
      clearInteractions(mockMusic);

      await service.setCustomSources(
        musicPath: null,
        sfxPaths: const {},
        clearEffectPack: SoundEffectPack.glass,
      );

      verifyNever(() => mockMusic.stop());
      for (final player in sfxPlayers) {
        verify(() => player.setSource(any())).called(1);
      }

      await service.dispose();
      await stateController.close();
    },
  );

  test('Wood stays the base pack while clear sounds use the selected variant',
      () async {
    final (mockMusic, stateController) = makeMusicPlayer();
    final sfxPlayers = <MockAudioPlayer>[];
    final service = AudioService(
      clearEffectPack: SoundEffectPack.glass,
      musicPlayer: mockMusic,
      sfxPlayerFactory: () {
        final player = makeSfxPlayer();
        sfxPlayers.add(player);
        return player;
      },
    );

    await service.init();

    for (var index = 0; index < AudioService.sfxNames.length; index++) {
      final name = AudioService.sfxNames[index];
      final source = verify(() => sfxPlayers[index].setSource(captureAny()))
          .captured
          .single as AssetSource;
      final expectedPack =
          name == 'clear' || name == 'tetris' ? 'glass' : 'wood';
      expect(
        source.path,
        startsWith('audio/sfx/${expectedPack}_$name.'),
      );
    }

    await service.dispose();
    await stateController.close();
  });

  group('AudioService — unexpected music pause recovery', () {
    test(
      'calls resume() (not play()) when the music player is externally paused',
      () async {
        final (mockMusic, stateController) = makeMusicPlayer();

        final service = AudioService(
          musicEnabled: true,
          musicPlayer: mockMusic,
          sfxPlayerFactory: makeSfxPlayer,
        );
        await service.init();
        await service.startMusic();

        // Wait for the playing state from startMusic() to propagate and clear
        // _isRestartingMusic before we inject the external pause.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        clearInteractions(mockMusic);

        // Simulate the OS externally pausing the music player
        // (e.g. Android audio focus loss when SFX plays).
        stateController.add(PlayerState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The service should resume from the current position, not restart.
        verify(() => mockMusic.resume()).called(1);
        verifyNever(() => mockMusic.play(any()));

        await stateController.close();
      },
    );

    test(
      'does not enter an infinite restart loop after unexpected pause',
      () async {
        final (mockMusic, stateController) = makeMusicPlayer();
        int playCount = 0;
        int resumeCount = 0;
        when(() => mockMusic.play(any())).thenAnswer((_) async {
          playCount++;
          if (playCount <= 5) {
            stateController.add(PlayerState.stopped);
            await Future<void>.delayed(const Duration(milliseconds: 1));
            stateController.add(PlayerState.playing);
          }
        });
        when(() => mockMusic.resume()).thenAnswer((_) async {
          resumeCount++;
          stateController.add(PlayerState.playing);
        });

        final service = AudioService(
          musicEnabled: true,
          musicPlayer: mockMusic,
          sfxPlayerFactory: makeSfxPlayer,
        );
        await service.init();
        await service.startMusic();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        playCount = 0;
        resumeCount = 0;

        // Externally pause the music.
        stateController.add(PlayerState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Should have recovered music exactly once — not looped.
        expect(
          playCount + resumeCount,
          greaterThan(0),
          reason: 'Music was not recovered after external pause',
        );
        expect(
          playCount + resumeCount,
          lessThanOrEqualTo(1),
          reason: 'AudioService entered an infinite restart loop',
        );

        await stateController.close();
      },
    );
  });

  test('changing the custom music source restarts enabled music', () async {
    final (mockMusic, stateController) = makeMusicPlayer();
    final service = AudioService(
      musicEnabled: true,
      musicPlayer: mockMusic,
      sfxPlayerFactory: makeSfxPlayer,
    );

    await service.init();
    await service.startMusic();
    clearInteractions(mockMusic);

    await service.setCustomSources(
      musicPath: '/tmp/custom-track.mp3',
      sfxPaths: const {},
      clearEffectPack: SoundEffectPack.wood,
    );

    verify(() => mockMusic.stop()).called(1);
    final source = verify(() => mockMusic.play(captureAny())).captured.single;
    expect(source, isA<DeviceFileSource>());
    expect((source as DeviceFileSource).path, '/tmp/custom-track.mp3');

    await stateController.close();
  });

  test('stopMusic prevents a stopped player from being restarted', () async {
    final (mockMusic, stateController) = makeMusicPlayer();
    final service = AudioService(
      musicPlayer: mockMusic,
      sfxPlayerFactory: makeSfxPlayer,
    );

    await service.init();
    await service.startMusic();
    clearInteractions(mockMusic);

    await service.stopMusic();
    stateController.add(PlayerState.stopped);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    verify(() => mockMusic.stop()).called(1);
    verifyNever(() => mockMusic.play(any()));
    verifyNever(() => mockMusic.resume());

    await stateController.close();
  });
}
