import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _musicPlayer;
  final AudioPlayer Function()? _sfxPlayerFactory;
  final Map<String, AudioPlayer> _sfxPlayers = {};

  bool musicEnabled;
  bool sfxEnabled;

  bool _musicIntentionallyPaused = true;
  // Guards against re-entrant restarts. Set when we initiate a play/resume,
  // cleared only when the player reports PlayerState.playing — NOT in a finally
  // block, because async stream events fire after the finally block runs and
  // would otherwise re-trigger the listener before the guard is cleared.
  bool _isRestartingMusic = false;

  AudioService({
    this.musicEnabled = true,
    this.sfxEnabled = true,
    AudioPlayer? musicPlayer,
    AudioPlayer Function()? sfxPlayerFactory,
  })  : _musicPlayer = musicPlayer ?? AudioPlayer(),
        _sfxPlayerFactory = sfxPlayerFactory;

  static const _sfxNames = [
    'move',
    'rotate',
    'drop',
    'clear',
    'tetris',
    'level_up',
    'hold',
    'game_over',
  ];

  static const _sfxVolumes = <String, double>{};

  Future<void> init() async {
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.5);
      await _musicPlayer.setAudioContext(AudioContext(
          android: AudioContextAndroid(
              usageType: AndroidUsageType.game,
              contentType: AndroidContentType.music,
              audioFocus: AndroidAudioFocus.gain,
              stayAwake: true)));

      _musicPlayer.onPlayerStateChanged.listen((state) async {
        if (state == PlayerState.playing) {
          // Clear the restart guard once the player is confirmed playing.
          _isRestartingMusic = false;
          return;
        }

        if (_isRestartingMusic || _musicIntentionallyPaused || !musicEnabled) {
          return;
        }

        if (state == PlayerState.paused) {
          // Externally paused (e.g. audio focus loss on Android).
          // Use resume() so the track continues from where it left off,
          // rather than play() which restarts from the beginning and also
          // triggers a 'stopped' state transition that would loop back here.
          _isRestartingMusic = true;
          try {
            await _musicPlayer.resume();
          } catch (_) {
            _isRestartingMusic = false;
          }
        } else if (state == PlayerState.stopped) {
          // Unexpectedly stopped — restart from beginning.
          await startMusic();
        }
      });

      for (final name in _sfxNames) {
        // Low latency mode (SoundPool on Android) doesn't request audio focus,
        // so SFX won't interrupt or pause the background music.
        final player = _sfxPlayerFactory?.call() ?? AudioPlayer();
        await player.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.game,
              contentType: AndroidContentType.sonification,

              // 🔑 CRITICAL
              audioFocus: AndroidAudioFocus.none,
            ),
          ),
        );
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setVolume(_sfxVolumes[name] ?? 0.8);
        await player.setSource(AssetSource('audio/sfx/$name.ogg'));
        _sfxPlayers[name] = player;
      }
    } catch (_) {}
  }

  Future<void> startMusic() async {
    _musicIntentionallyPaused = false;
    if (!musicEnabled) return;
    try {
      _isRestartingMusic = true;
      await _musicPlayer.play(AssetSource('audio/music/theme.ogg'));
      // _isRestartingMusic is cleared by the listener when PlayerState.playing
      // is received, not here — so that the guard is still active during the
      // async 'stopped' transition that play() causes.
    } catch (_) {
      _isRestartingMusic = false;
    }
  }

  Future<void> stopMusic() async {
    _musicIntentionallyPaused = true;
    _isRestartingMusic = false;
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }

  Future<void> pauseMusic() async {
    _musicIntentionallyPaused = true;
    _isRestartingMusic = false;
    try {
      await _musicPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeMusic() async {
    _musicIntentionallyPaused = false;
    if (!musicEnabled) return;
    try {
      final state = _musicPlayer.state;
      if (state == PlayerState.paused) {
        await _musicPlayer.resume();
      } else if (state != PlayerState.playing) {
        await startMusic();
      }
    } catch (_) {}
  }

  Future<void> setMusicEnabled(bool enabled) async {
    musicEnabled = enabled;
    if (enabled) {
      await resumeMusic();
    } else {
      await pauseMusic();
    }
  }

  void _playSfx(String name) {
    if (!sfxEnabled) return;
    try {
      final player = _sfxPlayers[name];
      if (player == null) return;
      player.play(AssetSource('audio/sfx/$name.ogg'));
    } catch (_) {}
  }

  void playMove() => _playSfx('move');
  void playRotate() => _playSfx('rotate');
  void playDrop() => _playSfx('drop');
  void playClear(int lines) => _playSfx(lines >= 4 ? 'tetris' : 'clear');
  void playLevelUp() => _playSfx('level_up');
  void playHold() => _playSfx('hold');
  void playGameOver() => _playSfx('game_over');

  Future<void> dispose() async {
    await _musicPlayer.dispose();
    for (final player in _sfxPlayers.values) {
      await player.dispose();
    }
  }
}
