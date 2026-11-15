import 'package:flutter/material.dart';

import '../models/tetromino.dart';

/// Classic orientations, with occupied bounds trimmed for the board renderer.
abstract final class ClassicRotation {
  // Classic orientationTable and rotationTable, ordered from spawn clockwise.
  // I, S and Z toggle the same two states in either direction; no kicks apply.
  // https://github.com/CelestialAmber/TetrisNESDisasm/blob/master/main.asm
  static final _states = <int, List<List<(int, int)>>>{
    Colors.purple.toARGB32(): [
      [(-1, 0), (0, 0), (1, 0), (0, 1)],
      [(0, -1), (-1, 0), (0, 0), (0, 1)],
      [(-1, 0), (0, 0), (1, 0), (0, -1)],
      [(0, -1), (0, 0), (1, 0), (0, 1)],
    ],
    Colors.blue.toARGB32(): [
      [(-1, 0), (0, 0), (1, 0), (1, 1)],
      [(0, -1), (0, 0), (-1, 1), (0, 1)],
      [(-1, -1), (-1, 0), (0, 0), (1, 0)],
      [(0, -1), (1, -1), (0, 0), (0, 1)],
    ],
    Colors.orange.toARGB32(): [
      [(-1, 0), (0, 0), (1, 0), (-1, 1)],
      [(-1, -1), (0, -1), (0, 0), (0, 1)],
      [(1, -1), (-1, 0), (0, 0), (1, 0)],
      [(0, -1), (0, 0), (0, 1), (1, 1)],
    ],
    Colors.red.toARGB32(): [
      [(-1, 0), (0, 0), (0, 1), (1, 1)],
      [(1, -1), (0, 0), (1, 0), (0, 1)],
    ],
    Colors.green.toARGB32(): [
      [(0, 0), (1, 0), (-1, 1), (0, 1)],
      [(0, -1), (0, 0), (1, 0), (1, 1)],
    ],
    Colors.cyan.toARGB32(): [
      [(-2, 0), (-1, 0), (0, 0), (1, 0)],
      [(0, -2), (0, -1), (0, 0), (0, 1)],
    ],
    Colors.yellow.toARGB32(): [
      [(-1, 0), (0, 0), (-1, 1), (0, 1)],
    ],
  };

  static List<(int, int)> _cells(Tetromino piece, int rotation) {
    final states = _states[piece.color.toARGB32()]!;
    return states[rotation % states.length];
  }

  /// Occupied top-left corner relative to the Classic piece origin.
  static (int, int) trimOffset(Tetromino piece, int rotation) {
    final cells = _cells(piece, rotation);
    return (
      cells.map((cell) => cell.$1).reduce((a, b) => a < b ? a : b),
      cells.map((cell) => cell.$2).reduce((a, b) => a < b ? a : b),
    );
  }

  /// Returns Classic geometry without changing the piece's identifying color.
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
