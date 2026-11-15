import 'package:block_drop/game/game_logic.dart';
import 'package:block_drop/game/gameplay_settings.dart';
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

  test('Classic preserves the original anchor for every piece and direction',
      () {
    for (final piece in Tetromino.pieces) {
      for (final clockwise in [true, false]) {
        logic.currentPiece = piece;
        logic.currentX = 3;
        logic.currentY = 5;
        logic.currentRotation = 0;
        var expected = piece;
        for (var turn = 0; turn < 4; turn++) {
          expected = clockwise ? expected.rotateRight() : expected.rotateLeft();
          if (clockwise) {
            logic.rotatePieceRight();
          } else {
            logic.rotatePieceLeft();
          }
          expect(logic.currentPiece!.shape, expected.shape);
          expect(logic.currentX, 3);
          expect(logic.currentY, 5);
        }
      }
    }
  });

  test('Modern retains its SRS pivot while Classic keeps the old anchor', () {
    for (final mode in RotationMode.values) {
      logic.gameplaySettings = GameplaySettings(rotationMode: mode);
      logic.currentPiece = Tetromino.pieces[2];
      logic.currentRotation = 0;
      logic.currentX = 3;
      logic.currentY = 5;
      logic.rotatePieceRight();
      expect(logic.currentX, mode == RotationMode.modern ? 4 : 3);
      expect(logic.currentY, 5);
    }
  });

  test('Classic kicks left at the right wall using the original offsets', () {
    logic.currentPiece = Tetromino.pieces[2].rotateRight();
    logic.currentRotation = 1;
    logic.currentX = 8;
    logic.currentY = 5;
    logic.rotatePieceRight();
    expect(logic.currentPiece!.shape,
        Tetromino.pieces[2].rotateRight().rotateRight().shape);
    expect(logic.currentX, 7);
    expect(logic.currentY, 5);
    expect(logic.currentRotation, 2);
  });

  test('Classic falls back to an upward kick when grounded', () {
    logic.currentPiece = Tetromino.pieces[2];
    logic.currentX = 3;
    logic.currentY = logic.board.length - 2;
    logic.rotatePieceRight();
    expect(logic.currentPiece!.shape, Tetromino.pieces[2].rotateRight().shape);
    expect(logic.currentX, 3);
    expect(logic.currentY, logic.board.length - 3);
  });

  test('blocked Classic rotation leaves the piece and orientation untouched',
      () {
    final piece = Tetromino.pieces[2];
    logic.currentPiece = piece;
    logic.currentX = 3;
    logic.currentY = 5;
    for (final row in logic.board) {
      row.fillRange(0, row.length, Colors.grey);
    }
    logic.rotatePieceLeft();
    expect(logic.currentPiece, same(piece));
    expect(logic.currentX, 3);
    expect(logic.currentY, 5);
    expect(logic.currentRotation, 0);
  });
}
