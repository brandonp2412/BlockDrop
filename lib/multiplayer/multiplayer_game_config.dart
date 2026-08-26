import '../models/tetromino.dart';
import '../game/gameplay_settings.dart';

/// Controls how multiplayer piece sequences are generated.
enum MultiplayerGameMode { independent, sharedPieces }

/// Wire-format helpers and lobby labels for [MultiplayerGameMode].
extension MultiplayerGameModeInfo on MultiplayerGameMode {
  /// Stable value sent over the multiplayer socket.
  String get wireName {
    return switch (this) {
      MultiplayerGameMode.independent => 'independent',
      MultiplayerGameMode.sharedPieces => 'shared_pieces',
    };
  }

  /// Short label used in the lobby mode selector.
  String get label {
    return switch (this) {
      MultiplayerGameMode.independent => 'Random',
      MultiplayerGameMode.sharedPieces => 'Fair',
    };
  }

  /// Parses a socket value, defaulting to the legacy independent mode.
  static MultiplayerGameMode fromWireName(Object? value) {
    return switch (value) {
      'shared_pieces' => MultiplayerGameMode.sharedPieces,
      _ => MultiplayerGameMode.independent,
    };
  }
}

/// Game-start settings shared by both players before a match begins.
class MultiplayerGameConfig {
  /// Piece sequence policy for this match.
  final MultiplayerGameMode mode;

  /// Seed used when [mode] is [MultiplayerGameMode.sharedPieces].
  final int? pieceSeed;

  /// Gameplay rules selected by the host for this match.
  final GameplaySettings gameplaySettings;

  /// Whether the hold mechanic is enabled for this match.
  bool get enableHold => gameplaySettings.holdEnabled;

  const MultiplayerGameConfig._({
    required this.mode,
    this.pieceSeed,
    this.gameplaySettings = GameplaySettings.defaults,
  });

  /// Creates a config where each player uses their own random 7-bag.
  const MultiplayerGameConfig.independent({
    bool enableHold = true,
    GameplaySettings? gameplaySettings,
  }) : this._(
          mode: MultiplayerGameMode.independent,
          gameplaySettings: gameplaySettings ??
              (enableHold
                  ? GameplaySettings.defaults
                  : const GameplaySettings(holdEnabled: false)),
        );

  /// Creates a config where both players use the same seeded 7-bag.
  const MultiplayerGameConfig.sharedPieces({
    required int pieceSeed,
    bool enableHold = true,
    GameplaySettings? gameplaySettings,
  }) : this._(
          mode: MultiplayerGameMode.sharedPieces,
          pieceSeed: pieceSeed,
          gameplaySettings: gameplaySettings ??
              (enableHold
                  ? GameplaySettings.defaults
                  : const GameplaySettings(holdEnabled: false)),
        );

  /// Decodes a `game_start` socket payload.
  factory MultiplayerGameConfig.fromGameStartMessage(
    Map<String, dynamic> message,
  ) {
    final mode = MultiplayerGameModeInfo.fromWireName(message['mode']);
    final seed = (message['piece_seed'] as num?)?.toInt();
    final gameplaySettings = GameplaySettings.fromMap({
      if (message['gameplay_settings'] is Map)
        ...(message['gameplay_settings'] as Map).cast<String, Object?>(),
      if (message.containsKey('enable_hold'))
        'enable_hold': message['enable_hold'],
    });

    if (mode == MultiplayerGameMode.sharedPieces && seed != null) {
      return MultiplayerGameConfig.sharedPieces(
        pieceSeed: seed,
        gameplaySettings: gameplaySettings,
      );
    }

    return MultiplayerGameConfig.independent(
      gameplaySettings: gameplaySettings,
    );
  }

  /// Encodes this config as a `game_start` socket payload.
  Map<String, dynamic> toGameStartMessage() {
    return {
      'type': 'game_start',
      'mode': mode.wireName,
      if (pieceSeed != null) 'piece_seed': pieceSeed,
      'enable_hold': enableHold,
      'gameplay_settings': gameplaySettings.toMap(),
    };
  }

  /// Creates the piece bag a local game should use for this config.
  TetrominoBag createPieceBag() {
    if (mode == MultiplayerGameMode.sharedPieces && pieceSeed != null) {
      return TetrominoBag(seed: pieceSeed);
    }

    return TetrominoBag();
  }
}
