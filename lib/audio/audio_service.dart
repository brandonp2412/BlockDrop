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
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.5);
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

      if (_musicIntentionallyPaused || !musicEnabled || _isIntentionallyStarting) {
        return;
      }

      if (state == PlayerState.paused) {
        await _musicPlayer.resume();
      } else if (state == PlayerState.stopped) {
        // Unexpectedly stopped — restart from beginning.
        await startMusic();
      }
    });

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
      await player.setVolume(_sfxVolumes[name] ?? 0.8);
      await player.setSource(AssetSource('audio/sfx/$name.$_audioExt'));
      _sfxPlayers[name] = player;
    }
  }

  Future<void> startMusic() async {
    _musicIntentionallyPaused = false;
    if (!musicEnabled) return;
    _isIntentionallyStarting = true;
    await _musicPlayer.play(AssetSource('audio/music/theme.$_audioExt'));
  }

  Future<void> stopMusic() async {
    _musicIntentionallyPaused = true;
    await _musicPlayer.stop();
  }

  Future<void> pauseMusic() async {
    _musicIntentionallyPaused = true;
    await _musicPlayer.pause();
  }

  Future<void> resumeMusic() async {
    _musicIntentionallyPaused = false;
    if (!musicEnabled) return;
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
    player.stop().then((_) => player.play(AssetSource('audio/sfx/$name.$_audioExt')));
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
