import 'package:flutter/material.dart';

import '../models/tetromino.dart';

/// NES Nintendo orientations, with occupied bounds trimmed for the board renderer.
abstract final class NintendoRotation {
  // NES orientationTable and rotationTable, ordered from spawn clockwise.
  // I, S and Z toggle the same two states in either direction; no kicks apply.
  // https://github.com/CelestialAmber/TetrisNESDisasm/blob/master/main.asm
  static final _states = <Color, List<List<(int, int)>>>{
    Colors.purple: [
      [(-1, 0), (0, 0), (1, 0), (0, 1)],
      [(0, -1), (-1, 0), (0, 0), (0, 1)],
      [(-1, 0), (0, 0), (1, 0), (0, -1)],
      [(0, -1), (0, 0), (1, 0), (0, 1)],
    ],
    Colors.blue: [
      [(-1, 0), (0, 0), (1, 0), (1, 1)],
      [(0, -1), (0, 0), (-1, 1), (0, 1)],
      [(-1, -1), (-1, 0), (0, 0), (1, 0)],
      [(0, -1), (1, -1), (0, 0), (0, 1)],
    ],
    Colors.orange: [
      [(-1, 0), (0, 0), (1, 0), (-1, 1)],
      [(-1, -1), (0, -1), (0, 0), (0, 1)],
      [(1, -1), (-1, 0), (0, 0), (1, 0)],
      [(0, -1), (0, 0), (0, 1), (1, 1)],
    ],
    Colors.red: [
      [(-1, 0), (0, 0), (0, 1), (1, 1)],
      [(1, -1), (0, 0), (1, 0), (0, 1)],
    ],
    Colors.green: [
      [(0, 0), (1, 0), (-1, 1), (0, 1)],
      [(0, -1), (0, 0), (1, 0), (1, 1)],
    ],
    Colors.cyan: [
      [(-2, 0), (-1, 0), (0, 0), (1, 0)],
      [(0, -2), (0, -1), (0, 0), (0, 1)],
    ],
    Colors.yellow: [
      [(-1, 0), (0, 0), (-1, 1), (0, 1)],
    ],
  };

  static List<(int, int)> _cells(Tetromino piece, int rotation) {
    final states = _states[piece.color]!;
    return states[rotation % states.length];
  }

  /// Occupied top-left corner relative to the NES piece origin.
  static (int, int) trimOffset(Tetromino piece, int rotation) {
    final cells = _cells(piece, rotation);
    return (
      cells.map((cell) => cell.$1).reduce((a, b) => a < b ? a : b),
      cells.map((cell) => cell.$2).reduce((a, b) => a < b ? a : b),
    );
  }

  /// Returns NES geometry without changing the piece's identifying color.
  static Tetromino pieceAt(Tetromino piece, int rotation) {
    final cells = _cells(piece, rotation);
    final (left, top) = trimOffset(piece, rotation);
    final right = cells.map((cell) => cell.$1).reduce((a, b) => a > b ? a : b);
    final bottom = cells.map((cell) => cell.$2).reduce((a, b) => a > b ? a : b);
    final shape = List.generate(
      bottom - top + 1,
      (_) => List.filled(right - left + 1, 0),
    );
    for (final (x, y) in cells) {
      shape[y - top][x - left] = 1;
    }
    return Tetromino(shape: shape, color: piece.color);
  }
}
