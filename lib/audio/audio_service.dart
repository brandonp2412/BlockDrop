import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import 'sfx_pack.dart';

/// Returns the audio file extension supported by the current platform.
/// Windows Media Foundation doesn't support Ogg Vorbis, so we use MP3 there.
String get _audioExt => Platform.isWindows ? 'mp3' : 'ogg';

class AudioService {
  final AudioPlayer _musicPlayer;
  final AudioPlayer Function()? _sfxPlayerFactory;
  final Map<String, AudioPlayer> _sfxPlayers = {};

  bool musicEnabled;
  bool sfxEnabled;
  String? customMusicPath;
  Map<String, String> customSfxPaths;
  DateTime? _lastMovePlayed;

  bool _musicIntentionallyPaused = true;
  bool _isIntentionallyStarting = false;
  Future<void>? _initialization;
  Future<void>? _musicInitialization;
  Future<void>? _musicStart;

  AudioService({
    this.musicEnabled = true,
    this.sfxEnabled = true,
    this.customMusicPath,
    this.customSfxPaths = const {},
    AudioPlayer? musicPlayer,
    AudioPlayer Function()? sfxPlayerFactory,
  })  : _musicPlayer = musicPlayer ?? AudioPlayer(),
        _sfxPlayerFactory = sfxPlayerFactory;

  /// Sound-effect slots that can be replaced with user-selected audio.
  static const sfxNames = [
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
    'clear': 0.5,
    'tetris': 0.62,
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
    await _musicPlayer.setVolume(Platform.isLinux ? 0.60 : 0.25);
    if (Platform.isAndroid) {
      await _musicPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.gain,
            stayAwake: true,
          ),
        ),
      );
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
    for (final name in sfxNames) {
      final player = _sfxPlayerFactory?.call() ?? AudioPlayer();
      if (Platform.isAndroid) {
        await player.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.game,
              contentType: AndroidContentType.sonification,
              // No audio focus so SFX won't pause background music.
              audioFocus: AndroidAudioFocus.none,
              stayAwake: true,
            ),
          ),
        );
      }
      final baseVolume = _sfxVolumes[name] ?? 0.5;
      final volume = Platform.isLinux
          ? (baseVolume * 2.5).clamp(0.0, 1.0).toDouble()
          : baseVolume;
      await player.setVolume(volume);
      _sfxPlayers[name] = player;
      try {
        await player.setSource(_sfxSource(name));
      } on Exception {
        // Keep the game usable when a desktop audio backend lacks a codec.
        // Playback will retry and fail silently until the backend is fixed.
      }
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
      await _musicPlayer.play(_musicSource());
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

  /// Reloads user-selected music and effects without recreating the service.
  Future<void> setCustomSources({
    String? musicPath,
    required Map<String, String> sfxPaths,
  }) async {
    final musicChanged = musicPath != customMusicPath;
    final sfxPathsChanged = sfxPaths.length != customSfxPaths.length ||
        sfxPaths.entries.any(
          (entry) => customSfxPaths[entry.key] != entry.value,
        );
    if (!musicChanged && !sfxPathsChanged) return;

    final shouldRestartMusic =
        musicChanged && musicEnabled && !_musicIntentionallyPaused;

    customMusicPath = musicPath;
    customSfxPaths = Map.of(sfxPaths);

    if (musicChanged) await _musicPlayer.stop();
    if (sfxPathsChanged) {
      for (final entry in _sfxPlayers.entries) {
        await entry.value.setSource(_sfxSource(entry.key));
      }
    }
    if (shouldRestartMusic) await startMusic();
  }

  void _playSfx(
    String name, {
    SoundEffectPack? packOverride,
    String? bundledAsset,
  }) async {
    if (!sfxEnabled) return;
    final player = _sfxPlayers[name];
    if (player == null) return;
    try {
      await player.stop();
      await player.play(
        _sfxSource(
          name,
          packOverride: packOverride,
          bundledAsset: bundledAsset,
        ),
      );
    } on Exception {
      // Audio is optional; a missing desktop codec must not crash the game.
    }
  }

  Source _musicSource() => customMusicPath == null
      ? AssetSource('audio/music/theme.$_audioExt')
      : DeviceFileSource(customMusicPath!);

  /// Resolves a bundled gameplay effect for [pack] and event [name].
  static Source bundledSfxSource(SoundEffectPack pack, String name) =>
      AssetSource('audio/sfx/${pack.name}_$name.$_audioExt');

  Source _sfxSource(
    String name, {
    SoundEffectPack? packOverride,
    String? bundledAsset,
  }) {
    final customPath = customSfxPaths[name];
    if (customPath != null) return DeviceFileSource(customPath);
    if (bundledAsset != null) {
      return AssetSource('audio/sfx/$bundledAsset.$_audioExt');
    }
    if (name == 'rotate') {
      return AssetSource('audio/sfx/subtle_rotate.$_audioExt');
    }

    final pack = packOverride ??
        (name == 'clear' || name == 'tetris'
            ? SoundEffectPack.heavy
            : SoundEffectPack.wood);
    return bundledSfxSource(pack, name);
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

  /// Plays a progressively weightier generated cue for one through four lines.
  /// User-selected clear/Tetris files still override the bundled cue.
  void playClear(int lines, {required int streak}) {
    final clearCount = lines.clamp(1, 4);
    _playSfx(
      lines >= 4 ? 'tetris' : 'clear',
      bundledAsset: 'clear_$clearCount',
    );
  }

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
