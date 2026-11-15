import 'package:block_drop/constants/game_constants.dart';
import 'package:block_drop/game/game_logic.dart';
import 'package:block_drop/game/gameplay_settings.dart';
import 'package:block_drop/game/classic_rotation.dart';
import 'package:block_drop/models/tetromino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GameLogic logic;
  setUp(() {
    logic = GameLogic(
        gameplaySettings:
            const GameplaySettings(rotationMode: RotationMode.classic));
  });
  tearDown(() => logic.dispose());

  void setPiece(int index, {int rotation = 0, int x = 3, int y = 5}) {
    logic.currentPiece =
        ClassicRotation.pieceAt(Tetromino.pieces[index], rotation);
    logic.currentRotation = rotation;
    logic.currentX = x;
    logic.currentY = y;
  }

  test('restored Classic pieces can rotate, spawn and swap hold', () {
    logic.isGameRunning = true;
    for (var index = 0; index < Tetromino.pieces.length; index++) {
      setPiece(index);
      logic.nextPiece = Tetromino.pieces[index];
      logic.heldPiece = Tetromino.pieces[index];
      logic.canHold = true;
      final snapshot = logic.createSnapshot();
      expect(logic.restoreSnapshot(snapshot), isTrue);
      logic.isPaused = false;
      for (var turn = 1; turn <= 4; turn++) {
        logic.rotatePieceRight();
        expect(logic.currentPiece!.shape,
            ClassicRotation.pieceAt(Tetromino.pieces[index], turn).shape);
      }
      logic.holdPiece();
      expect(logic.currentPiece!.shape,
          ClassicRotation.pieceAt(Tetromino.pieces[index], 0).shape);
      logic.spawnNewPiece();
      expect(logic.currentPiece!.shape,
          ClassicRotation.pieceAt(Tetromino.pieces[index], 0).shape);
    }
  });

  test(
      'Classic spawns Classic orientations and centers the I on its Classic origin',
      () {
    final expected = [
      [
        [1, 1, 1, 1]
      ],
      [
        [1, 1],
        [1, 1]
      ],
      [
        [1, 1, 1],
        [0, 1, 0]
      ],
      [
        [0, 1, 1],
        [1, 1, 0]
      ],
      [
        [1, 1, 0],
        [0, 1, 1]
      ],
      [
        [1, 1, 1],
        [0, 0, 1]
      ],
      [
        [1, 1, 1],
        [1, 0, 0]
      ],
    ];
    for (var index = 0; index < Tetromino.pieces.length; index++) {
      logic.nextPiece = Tetromino.pieces[index];
      logic.spawnNewPiece();
      expect(logic.currentPiece!.shape, expected[index]);
      expect(logic.currentX, index == 0 ? 3 : 4);
      expect(logic.currentY, GameConstants.previewRows);
    }
  });

  test('Classic T rotates around its fixed origin in both directions', () {
    for (final clockwise in [true, false]) {
      setPiece(2);
      final shapes = clockwise
          ? [
              [
                [0, 1],
                [1, 1],
                [0, 1]
              ],
              [
                [0, 1, 0],
                [1, 1, 1]
              ],
              [
                [1, 0],
                [1, 1],
                [1, 0]
              ],
              [
                [1, 1, 1],
                [0, 1, 0]
              ],
            ]
          : [
              [
                [1, 0],
                [1, 1],
                [1, 0]
              ],
              [
                [0, 1, 0],
                [1, 1, 1]
              ],
              [
                [0, 1],
                [1, 1],
                [0, 1]
              ],
              [
                [1, 1, 1],
                [0, 1, 0]
              ],
            ];
      for (var turn = 0; turn < 4; turn++) {
        clockwise ? logic.rotatePieceRight() : logic.rotatePieceLeft();
        expect(logic.currentPiece!.shape, shapes[turn]);
        expect(logic.currentX,
            !clockwise && turn == 0 || clockwise && turn == 2 ? 4 : 3);
        expect(logic.currentY, turn == 3 ? 5 : 4);
      }
    }
  });

  test('Classic J and L use their asymmetric clockwise orientations', () {
    final expected = {
      5: [
        [
          [0, 1],
          [0, 1],
          [1, 1]
        ],
        [
          [1, 0, 0],
          [1, 1, 1]
        ],
        [
          [1, 1],
          [1, 0],
          [1, 0]
        ],
        [
          [1, 1, 1],
          [0, 0, 1]
        ],
      ],
      6: [
        [
          [1, 1],
          [0, 1],
          [0, 1]
        ],
        [
          [0, 0, 1],
          [1, 1, 1]
        ],
        [
          [1, 0],
          [1, 0],
          [1, 1]
        ],
        [
          [1, 1, 1],
          [1, 0, 0]
        ],
      ],
    };
    for (final entry in expected.entries) {
      setPiece(entry.key);
      for (final shape in entry.value) {
        logic.rotatePieceRight();
        expect(logic.currentPiece!.shape, shape);
      }
      expect((logic.currentX, logic.currentY), (3, 5));
    }
  });

  test('four turns in either direction return every piece without drift', () {
    for (var index = 0; index < Tetromino.pieces.length; index++) {
      for (final clockwise in [true, false]) {
        setPiece(index);
        final original = logic.currentPiece!.shape;
        for (var turn = 0; turn < 4; turn++) {
          clockwise ? logic.rotatePieceRight() : logic.rotatePieceLeft();
        }
        expect(logic.currentPiece!.shape, original);
        expect(
            (logic.currentX, logic.currentY, logic.currentRotation), (3, 5, 0));
      }
    }
  });

  test('I, S and Z toggle the same two positions in either direction', () {
    for (final index in [0, 3, 4]) {
      setPiece(index);
      logic.rotatePieceRight();
      final rightShape = logic.currentPiece!.shape;
      final rightPosition = (logic.currentX, logic.currentY);
      setPiece(index);
      logic.rotatePieceLeft();
      expect(logic.currentPiece!.shape, rightShape);
      expect((logic.currentX, logic.currentY), rightPosition);
      logic.rotatePieceLeft();
      expect(logic.currentPiece!.shape,
          ClassicRotation.pieceAt(Tetromino.pieces[index], 0).shape);
      expect((logic.currentX, logic.currentY), (3, 5));
    }
  });

  test('Classic rejects wall collisions instead of kicking sideways', () {
    setPiece(2, rotation: 3, x: 0);
    final original = logic.currentPiece;
    logic.rotatePieceRight();
    expect(logic.currentPiece, same(original));
    expect((logic.currentX, logic.currentY, logic.currentRotation), (0, 5, 3));
  });

  test('Classic rejects floor collisions instead of kicking upward', () {
    setPiece(0, y: logic.board.length - 1);
    final original = logic.currentPiece;
    logic.rotatePieceRight();
    expect(logic.currentPiece, same(original));
    expect(logic.currentY, logic.board.length - 1);
    expect(logic.currentRotation, 0);
  });

  test('Classic rejects stack collisions without changing orientation', () {
    setPiece(2);
    logic.board[4][4] = Colors.grey;
    final original = logic.currentPiece;
    logic.rotatePieceLeft();
    expect(logic.currentPiece, same(original));
    expect((logic.currentX, logic.currentY, logic.currentRotation), (3, 5, 0));
  });

  test('held Classic pieces return in their Classic spawn orientation', () {
    setPiece(2, rotation: 1);
    logic.holdPiece();
    logic.canHold = true;
    logic.holdPiece();
    expect(logic.currentPiece!.shape, [
      [1, 1, 1],
      [0, 1, 0]
    ]);
    expect(logic.currentRotation, 0);
    expect(logic.currentX, 4);
  });
}
