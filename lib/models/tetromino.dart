import 'package:flutter/material.dart';
import 'dart:math';

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

  static Tetromino random() {
    final random = Random();
    return pieces[random.nextInt(pieces.length)];
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
