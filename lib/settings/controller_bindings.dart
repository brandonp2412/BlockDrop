import 'package:flutter/services.dart';

/// Gameplay operations that can be assigned to a controller button.
enum GameplayAction {
  moveLeft('Move left'),
  moveRight('Move right'),
  softDrop('Soft drop'),
  rotateLeft('Rotate left'),
  rotateRight('Rotate right'),
  hardDrop('Hard drop'),
  hold('Hold');

  const GameplayAction(this.label);

  /// Human-readable name shown in controller settings.
  final String label;
}

/// Default controller layout, including D-pad and common face buttons.
/// Recommended layout used until the player customizes controller input.
const defaultControllerBindings = <GameplayAction, LogicalKeyboardKey>{
  GameplayAction.moveLeft: LogicalKeyboardKey.arrowLeft,
  GameplayAction.moveRight: LogicalKeyboardKey.arrowRight,
  GameplayAction.softDrop: LogicalKeyboardKey.arrowDown,
  GameplayAction.rotateLeft: LogicalKeyboardKey.gameButtonB,
  GameplayAction.rotateRight: LogicalKeyboardKey.gameButtonA,
  GameplayAction.hardDrop: LogicalKeyboardKey.gameButtonY,
  GameplayAction.hold: LogicalKeyboardKey.gameButtonX,
};

/// Returns a concise label for a logical controller key.
String controllerKeyLabel(LogicalKeyboardKey key) {
  final labels = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.arrowLeft: 'D-pad left',
    LogicalKeyboardKey.arrowRight: 'D-pad right',
    LogicalKeyboardKey.arrowDown: 'D-pad down',
    LogicalKeyboardKey.arrowUp: 'D-pad up',
    LogicalKeyboardKey.gameButtonA: 'Button A',
    LogicalKeyboardKey.gameButtonB: 'Button B',
    LogicalKeyboardKey.gameButtonX: 'Button X',
    LogicalKeyboardKey.gameButtonY: 'Button Y',
    LogicalKeyboardKey.gameButtonLeft1: 'Left bumper',
    LogicalKeyboardKey.gameButtonLeft2: 'Left trigger',
    LogicalKeyboardKey.gameButtonRight1: 'Right bumper',
    LogicalKeyboardKey.gameButtonRight2: 'Right trigger',
    LogicalKeyboardKey.gameButtonSelect: 'Select',
    LogicalKeyboardKey.gameButtonStart: 'Start',
    LogicalKeyboardKey.gameButtonThumbLeft: 'Left stick',
    LogicalKeyboardKey.gameButtonThumbRight: 'Right stick',
  };
  return labels[key] ??
      (key.keyLabel.isEmpty ? 'Button ${key.keyId}' : key.keyLabel);
}
