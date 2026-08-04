import '../models/tetromino.dart';

/// Controls how multiplayer piece sequences are generated.
enum MultiplayerGameMode {
  independent,
  sharedPieces,
}

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

  /// Whether the hold mechanic is enabled for this match.
  final bool enableHold;

  const MultiplayerGameConfig._({
    required this.mode,
    this.pieceSeed,
    this.enableHold = true,
  });

  /// Creates a config where each player uses their own random 7-bag.
  const MultiplayerGameConfig.independent({bool enableHold = true})
      : this._(mode: MultiplayerGameMode.independent, enableHold: enableHold);

  /// Creates a config where both players use the same seeded 7-bag.
  const MultiplayerGameConfig.sharedPieces({
    required int pieceSeed,
    bool enableHold = true,
  }) : this._(
          mode: MultiplayerGameMode.sharedPieces,
          pieceSeed: pieceSeed,
          enableHold: enableHold,
        );

  /// Decodes a `game_start` socket payload.
  factory MultiplayerGameConfig.fromGameStartMessage(
    Map<String, dynamic> message,
  ) {
    final mode = MultiplayerGameModeInfo.fromWireName(message['mode']);
    final seed = (message['piece_seed'] as num?)?.toInt();
    final enableHold = message['enable_hold'] as bool? ?? true;

    if (mode == MultiplayerGameMode.sharedPieces && seed != null) {
      return MultiplayerGameConfig.sharedPieces(
        pieceSeed: seed,
        enableHold: enableHold,
      );
    }

    return MultiplayerGameConfig.independent(enableHold: enableHold);
  }

  /// Encodes this config as a `game_start` socket payload.
  Map<String, dynamic> toGameStartMessage() {
    return {
      'type': 'game_start',
      'mode': mode.wireName,
      if (pieceSeed != null) 'piece_seed': pieceSeed,
      'enable_hold': enableHold,
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
