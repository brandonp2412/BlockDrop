import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:block_drop/audio/audio_service.dart';

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
    when(() => mock.setReleaseMode(any())).thenAnswer((_) async {});
    when(() => mock.setAudioContext(any())).thenAnswer((_) async {});
    when(() => mock.setVolume(any())).thenAnswer((_) async {});
    when(() => mock.state).thenReturn(PlayerState.playing);
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
    when(() => mock.dispose()).thenAnswer((_) async {});

    return (mock, stateController);
  }

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
}
