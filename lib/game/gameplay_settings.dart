import '../constants/game_constants.dart';

/// Controls whether hold is available only from its panel or also via back.
enum HoldInteractionMode {
  panelOnly,
  panelAndBackGesture;

  /// Stable representation used by preferences and multiplayer messages.
  String get wireName => switch (this) {
        panelOnly => 'panel_only',
        panelAndBackGesture => 'panel_and_back',
      };

  /// Parses persisted and network values with a backwards-compatible default.
  static HoldInteractionMode fromWireName(Object? value) => switch (value) {
        'panel_only' => panelOnly,
        _ => panelAndBackGesture,
      };
}

/// Rules that determine the pace and available controls for a match.
class GameplaySettings {
  /// Sentinel used by [maximumLevel] to represent no level cap.
  static const int unlimitedLevels = 0;

  /// Default rules used when no saved or network configuration is available.
  static const defaults = GameplaySettings();

  /// Delay in milliseconds between automatic downward movements at level one.
  final int initialDropSpeed;

  /// Milliseconds removed from the automatic drop delay at each new level.
  final int speedIncrement;

  /// Highest attainable level, or [unlimitedLevels] for no cap.
  final int maximumLevel;

  /// Number of cleared lines required for each level increase.
  final int linesPerLevel;

  /// Whether manual downward movement and swipe hard-drop are enabled.
  final bool softDropEnabled;

  /// Whether pieces can be stored and swapped.
  final bool holdEnabled;

  /// Surfaces that invoke hold when [holdEnabled] is true.
  final HoldInteractionMode holdInteractionMode;

  const GameplaySettings({
    this.initialDropSpeed = GameConstants.initialDropSpeed,
    this.speedIncrement = GameConstants.speedIncrement,
    this.maximumLevel = 20,
    this.linesPerLevel = GameConstants.linesPerLevel,
    this.softDropEnabled = true,
    this.holdEnabled = true,
    this.holdInteractionMode = HoldInteractionMode.panelAndBackGesture,
  });

  /// Returns the level for [clearedLines], respecting [maximumLevel].
  int levelForLines(int clearedLines) {
    final uncappedLevel = clearedLines ~/ linesPerLevel + 1;
    return maximumLevel == unlimitedLevels
        ? uncappedLevel
        : uncappedLevel.clamp(1, maximumLevel);
  }

  /// Returns the automatic drop delay for [level].
  int dropSpeedForLevel(int level) =>
      (initialDropSpeed - (level - 1) * speedIncrement).clamp(
        GameConstants.minDropSpeed,
        initialDropSpeed,
      );

  /// Creates rules from persisted or network values, safely clamping bad input.
  factory GameplaySettings.fromMap(Map<String, Object?> values) {
    int integer(String key, int fallback, int min, int max) {
      final value = values[key];
      return value is num ? value.toInt().clamp(min, max) : fallback;
    }

    bool boolean(String key, bool fallback) {
      final value = values[key];
      return value is bool ? value : fallback;
    }

    final holdEnabled = values['hold_enabled'] is bool
        ? values['hold_enabled']! as bool
        : boolean('enable_hold', true);

    return GameplaySettings(
      initialDropSpeed: integer('initial_drop_speed', 800, 200, 2000),
      speedIncrement: integer('speed_increment', 50, 0, 200),
      maximumLevel: integer('maximum_level', 20, 0, 100),
      linesPerLevel: integer('lines_per_level', 10, 1, 50),
      softDropEnabled: boolean('soft_drop_enabled', true),
      holdEnabled: holdEnabled,
      holdInteractionMode: HoldInteractionMode.fromWireName(
        values['hold_interaction_mode'],
      ),
    );
  }

  /// Encodes the rules for preferences or a multiplayer payload.
  Map<String, Object> toMap() => {
        'initial_drop_speed': initialDropSpeed,
        'speed_increment': speedIncrement,
        'maximum_level': maximumLevel,
        'lines_per_level': linesPerLevel,
        'soft_drop_enabled': softDropEnabled,
        'hold_enabled': holdEnabled,
        'hold_interaction_mode': holdInteractionMode.wireName,
      };

  /// Returns a copy with selected values replaced.
  GameplaySettings copyWith({
    int? initialDropSpeed,
    int? speedIncrement,
    int? maximumLevel,
    int? linesPerLevel,
    bool? softDropEnabled,
    bool? holdEnabled,
    HoldInteractionMode? holdInteractionMode,
  }) =>
      GameplaySettings(
        initialDropSpeed: initialDropSpeed ?? this.initialDropSpeed,
        speedIncrement: speedIncrement ?? this.speedIncrement,
        maximumLevel: maximumLevel ?? this.maximumLevel,
        linesPerLevel: linesPerLevel ?? this.linesPerLevel,
        softDropEnabled: softDropEnabled ?? this.softDropEnabled,
        holdEnabled: holdEnabled ?? this.holdEnabled,
        holdInteractionMode: holdInteractionMode ?? this.holdInteractionMode,
      );
}
