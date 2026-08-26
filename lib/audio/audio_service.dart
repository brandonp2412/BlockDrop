import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

/// Returns the audio file extension supported by the current platform.
/// Windows Media Foundation doesn't support Ogg Vorbis, so we use MP3 there.
String get _audioExt => Platform.isWindows ? 'mp3' : 'ogg';

class AudioService {
  final AudioPlayer _musicPlayer;
  final AudioPlayer Function()? _sfxPlayerFactory;
  final Map<String, AudioPlayer> _sfxPlayers = {};

  bool musicEnabled;
  bool sfxEnabled;
  DateTime? _lastMovePlayed;

  bool _musicIntentionallyPaused = true;
  bool _isIntentionallyStarting = false;
  Future<void>? _initialization;
  Future<void>? _musicInitialization;
  Future<void>? _musicStart;

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

  static const _sfxVolumes = <String, double>{
    'move': 0.26,
    'rotate': 0.34,
    'drop': 0.42,
    'clear': 0.26,
    'tetris': 0.32,
    'level_up': 0.3,
    'hold': 0.32,
    'game_over': 0.38,
  };

  Future<void> init() => _initialization ??= Future.wait([
        _ensureMusicInitialized(),
        _initializeSfx(),
      ]);

  Future<void> _ensureMusicInitialized() =>
      _musicInitialization ??= _initializeMusic();

  Future<void> _initializeMusic() async {
    await _musicPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.25);
    if (Platform.isAndroid) {
      await _musicPlayer.setAudioContext(AudioContext(
          android: AudioContextAndroid(
              usageType: AndroidUsageType.game,
              contentType: AndroidContentType.music,
              audioFocus: AndroidAudioFocus.gain,
              stayAwake: true)));
    }

    _musicPlayer.onPlayerStateChanged.listen((state) async {
      if (state == PlayerState.playing) {
        _isIntentionallyStarting = false;
        return;
      }

      if (_musicIntentionallyPaused ||
          !musicEnabled ||
          _isIntentionallyStarting) {
        return;
      }

      if (state == PlayerState.paused) {
        await _musicPlayer.resume();
      } else if (state == PlayerState.stopped) {
        // Unexpectedly stopped — restart from beginning.
        await startMusic();
      }
    });
  }

  Future<void> _initializeSfx() async {
    for (final name in _sfxNames) {
      final player = _sfxPlayerFactory?.call() ?? AudioPlayer();
      if (Platform.isAndroid) {
        await player.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.game,
              contentType: AndroidContentType.sonification,
              // 🔑 CRITICAL: no audio focus so SFX won't pause background music.
              audioFocus: AndroidAudioFocus.none,
              stayAwake: true,
            ),
          ),
        );
      }
      await player.setVolume(_sfxVolumes[name] ?? 0.5);
      await player.setSource(AssetSource('audio/sfx/$name.$_audioExt'));
      _sfxPlayers[name] = player;
    }
  }

  Future<void> startMusic() {
    _musicIntentionallyPaused = false;
    return _musicStart ??= _startMusic().whenComplete(() => _musicStart = null);
  }

  Future<void> _startMusic() async {
    await _ensureMusicInitialized();
    if (!musicEnabled || _musicIntentionallyPaused) return;
    if (_musicPlayer.state == PlayerState.playing) return;
    _isIntentionallyStarting = true;
    try {
      await _musicPlayer.play(AssetSource('audio/music/theme.$_audioExt'));
    } finally {
      if (_musicPlayer.state != PlayerState.playing) {
        _isIntentionallyStarting = false;
      }
    }
  }

  Future<void> stopMusic() async {
    _musicIntentionallyPaused = true;
    await _musicPlayer.stop();
  }

  Future<void> pauseMusic() async {
    _musicIntentionallyPaused = true;
    await _ensureMusicInitialized();
    await _musicPlayer.pause();
  }

  Future<void> resumeMusic() async {
    _musicIntentionallyPaused = false;
    await _ensureMusicInitialized();
    if (!musicEnabled || _musicIntentionallyPaused) return;
    final state = _musicPlayer.state;
    if (state == PlayerState.paused) {
      await _musicPlayer.resume();
    } else if (state != PlayerState.playing) {
      await startMusic();
    }
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
    final player = _sfxPlayers[name];
    if (player == null) return;
    player
        .stop()
        .then((_) => player.play(AssetSource('audio/sfx/$name.$_audioExt')));
  }

  void playMove() {
    final now = DateTime.now();
    if (_lastMovePlayed != null &&
        now.difference(_lastMovePlayed!).inMilliseconds < 80) {
      return;
    }
    _lastMovePlayed = now;
    _playSfx('move');
  }

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
