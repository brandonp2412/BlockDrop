import 'dart:math';

import 'package:flutter/material.dart';

class Tetromino {
  final List<List<int>> shape;
  final Color color;

  const Tetromino({required this.shape, required this.color});

  static final List<Tetromino> pieces = [
    // I piece
    Tetromino(
      shape: [
        [1, 1, 1, 1],
      ],
      color: Colors.cyan,
    ),
    // O piece
    Tetromino(
      shape: [
        [1, 1],
        [1, 1],
      ],
      color: Colors.yellow,
    ),
    // T piece
    Tetromino(
      shape: [
        [0, 1, 0],
        [1, 1, 1],
      ],
      color: Colors.purple,
    ),
    // S piece
    Tetromino(
      shape: [
        [0, 1, 1],
        [1, 1, 0],
      ],
      color: Colors.green,
    ),
    // Z piece
    Tetromino(
      shape: [
        [1, 1, 0],
        [0, 1, 1],
      ],
      color: Colors.red,
    ),
    // J piece
    Tetromino(
      shape: [
        [1, 0, 0],
        [1, 1, 1],
      ],
      color: Colors.blue,
    ),
    // L piece
    Tetromino(
      shape: [
        [0, 0, 1],
        [1, 1, 1],
      ],
      color: Colors.orange,
    ),
  ];

  static final TetrominoBag _defaultBag = TetrominoBag();

  static Tetromino random() {
    return _defaultBag.next();
  }

  static void resetBag() {
    _defaultBag.reset();
  }

  Tetromino rotate() {
    return rotateRight();
  }

  Tetromino rotateRight() {
    List<List<int>> rotated = List.generate(
      shape[0].length,
      (i) => List.generate(shape.length, (j) => shape[shape.length - 1 - j][i]),
    );
    return Tetromino(shape: rotated, color: color);
  }

  Tetromino rotateLeft() {
    List<List<int>> rotated = List.generate(
      shape[0].length,
      (i) =>
          List.generate(shape.length, (j) => shape[j][shape[0].length - 1 - i]),
    );
    return Tetromino(shape: rotated, color: color);
  }
}

/// Produces tetrominoes using the standard 7-bag shuffle.
class TetrominoBag {
  final int? _seed;
  final List<Tetromino> _bag = [];
  late Random _random;

  /// Creates a random bag, or a deterministic bag when [seed] is provided.
  TetrominoBag({int? seed}) : _seed = seed {
    _random = _createRandom();
  }

  Random _createRandom() {
    return _seed == null ? Random() : Random(_seed);
  }

  /// Returns the next piece, refilling and shuffling the bag when needed.
  Tetromino next() {
    if (_bag.isEmpty) {
      _bag.addAll(Tetromino.pieces);
      _bag.shuffle(_random);
    }

    return _bag.removeLast();
  }

  /// Clears pending pieces and restarts deterministic bags from their seed.
  void reset() {
    _bag.clear();
    if (_seed != null) {
      _random = _createRandom();
    }
  }
}
