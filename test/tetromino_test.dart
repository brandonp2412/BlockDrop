import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:block_drop/models/tetromino.dart';

void main() {
  group('Tetromino Tests', () {
    test('should have correct number of pieces', () {
      expect(Tetromino.pieces.length, 7);
    });

    test('should generate random pieces', () {
      final piece1 = Tetromino.random();
      final piece2 = Tetromino.random();

      expect(piece1, isNotNull);
      expect(piece2, isNotNull);
      expect(piece1.shape, isNotEmpty);
      expect(piece2.shape, isNotEmpty);
      expect(piece1.color, isNotNull);
      expect(piece2.color, isNotNull);
    });

    test('should rotate I piece correctly', () {
      final iPiece = Tetromino(
        shape: [
          [1, 1, 1, 1],
        ],
        color: Colors.cyan,
      );

      final rotatedRight = iPiece.rotateRight();
      expect(rotatedRight.shape.length, 4);
      expect(rotatedRight.shape[0].length, 1);
      expect(rotatedRight.color, Colors.cyan);

      final rotatedLeft = iPiece.rotateLeft();
      expect(rotatedLeft.shape.length, 4);
      expect(rotatedLeft.shape[0].length, 1);
      expect(rotatedLeft.color, Colors.cyan);
    });

    test('should rotate O piece correctly (should remain same)', () {
      final oPiece = Tetromino(
        shape: [
          [1, 1],
          [1, 1],
        ],
        color: Colors.yellow,
      );

      final rotatedRight = oPiece.rotateRight();
      expect(rotatedRight.shape, equals(oPiece.shape));
      expect(rotatedRight.color, Colors.yellow);

      final rotatedLeft = oPiece.rotateLeft();
      expect(rotatedLeft.shape, equals(oPiece.shape));
      expect(rotatedLeft.color, Colors.yellow);
    });

    test('should rotate T piece correctly', () {
      final tPiece = Tetromino(
        shape: [
          [0, 1, 0],
          [1, 1, 1],
        ],
        color: Colors.purple,
      );

      final rotatedRight = tPiece.rotateRight();
      expect(rotatedRight.shape.length, 3);
      expect(rotatedRight.shape[0].length, 2);
      expect(rotatedRight.color, Colors.purple);

      // Verify the actual rotation
      expect(
        rotatedRight.shape,
        equals([
          [1, 0],
          [1, 1],
          [1, 0],
        ]),
      );

      final rotatedLeft = tPiece.rotateLeft();
      expect(rotatedLeft.shape.length, 3);
      expect(rotatedLeft.shape[0].length, 2);
      expect(rotatedLeft.color, Colors.purple);

      // Verify the actual rotation
      expect(
        rotatedLeft.shape,
        equals([
          [0, 1],
          [1, 1],
          [0, 1],
        ]),
      );
    });

    test('should rotate L piece correctly', () {
      final lPiece = Tetromino(
        shape: [
          [0, 0, 1],
          [1, 1, 1],
        ],
        color: Colors.orange,
      );

      final rotatedRight = lPiece.rotateRight();
      expect(rotatedRight.shape.length, 3);
      expect(rotatedRight.shape[0].length, 2);
      expect(rotatedRight.color, Colors.orange);

      // Verify the actual rotation
      expect(
        rotatedRight.shape,
        equals([
          [1, 0],
          [1, 0],
          [1, 1],
        ]),
      );
    });

    test('should rotate J piece correctly', () {
      final jPiece = Tetromino(
        shape: [
          [1, 0, 0],
          [1, 1, 1],
        ],
        color: Colors.blue,
      );

      final rotatedRight = jPiece.rotateRight();
      expect(rotatedRight.shape.length, 3);
      expect(rotatedRight.shape[0].length, 2);
      expect(rotatedRight.color, Colors.blue);

      // Verify the actual rotation
      expect(
        rotatedRight.shape,
        equals([
          [1, 1],
          [1, 0],
          [1, 0],
        ]),
      );
    });

    test('should rotate S piece correctly', () {
      final sPiece = Tetromino(
        shape: [
          [0, 1, 1],
          [1, 1, 0],
        ],
        color: Colors.green,
      );

      final rotatedRight = sPiece.rotateRight();
      expect(rotatedRight.shape.length, 3);
      expect(rotatedRight.shape[0].length, 2);
      expect(rotatedRight.color, Colors.green);

      // Verify the actual rotation
      expect(
        rotatedRight.shape,
        equals([
          [1, 0],
          [1, 1],
          [0, 1],
        ]),
      );
    });

    test('should rotate Z piece correctly', () {
      final zPiece = Tetromino(
        shape: [
          [1, 1, 0],
          [0, 1, 1],
        ],
        color: Colors.red,
      );

      final rotatedRight = zPiece.rotateRight();
      expect(rotatedRight.shape.length, 3);
      expect(rotatedRight.shape[0].length, 2);
      expect(rotatedRight.color, Colors.red);

      // Verify the actual rotation
      expect(
        rotatedRight.shape,
        equals([
          [0, 1],
          [1, 1],
          [1, 0],
        ]),
      );
    });

    test('should maintain color after rotation', () {
      for (final piece in Tetromino.pieces) {
        final rotatedRight = piece.rotateRight();
        final rotatedLeft = piece.rotateLeft();

        expect(rotatedRight.color, piece.color);
        expect(rotatedLeft.color, piece.color);
      }
    });

    test('should have valid shapes for all pieces', () {
      for (final piece in Tetromino.pieces) {
        expect(piece.shape, isNotEmpty);
        expect(piece.shape[0], isNotEmpty);

        // All rows should have the same length
        final expectedLength = piece.shape[0].length;
        for (final row in piece.shape) {
          expect(row.length, expectedLength);
        }

        // Should contain at least one block
        bool hasBlock = false;
        for (final row in piece.shape) {
          for (final cell in row) {
            if (cell == 1) {
              hasBlock = true;
              break;
            }
          }
          if (hasBlock) break;
        }
        expect(hasBlock, true);
      }
    });

    test('should have unique colors for all pieces', () {
      final colors = Tetromino.pieces.map((piece) => piece.color).toSet();
      expect(colors.length, Tetromino.pieces.length);
    });

    test('rotate method should call rotateRight', () {
      final tPiece = Tetromino(
        shape: [
          [0, 1, 0],
          [1, 1, 1],
        ],
        color: Colors.purple,
      );

      final rotated = tPiece.rotate();
      final rotatedRight = tPiece.rotateRight();

      expect(rotated.shape, equals(rotatedRight.shape));
      expect(rotated.color, equals(rotatedRight.color));
    });

    test('should handle multiple rotations correctly', () {
      final tPiece = Tetromino(
        shape: [
          [0, 1, 0],
          [1, 1, 1],
        ],
        color: Colors.purple,
      );

      // Rotate 4 times right should return to original (approximately)
      var rotated = tPiece;
      for (int i = 0; i < 4; i++) {
        rotated = rotated.rotateRight();
      }

      // Should be back to original orientation
      expect(rotated.shape, equals(tPiece.shape));
      expect(rotated.color, tPiece.color);
    });

    test('should handle left rotation correctly', () {
      final tPiece = Tetromino(
        shape: [
          [0, 1, 0],
          [1, 1, 1],
        ],
        color: Colors.purple,
      );

      // Rotate 4 times left should return to original (approximately)
      var rotated = tPiece;
      for (int i = 0; i < 4; i++) {
        rotated = rotated.rotateLeft();
      }

      // Should be back to original orientation
      expect(rotated.shape, equals(tPiece.shape));
      expect(rotated.color, tPiece.color);
    });

    test('left and right rotations should be opposite', () {
      final tPiece = Tetromino(
        shape: [
          [0, 1, 0],
          [1, 1, 1],
        ],
        color: Colors.purple,
      );

      // Rotating left then right should get back to original
      final rotatedLeft = tPiece.rotateLeft();
      final backToOriginal = rotatedLeft.rotateRight();

      expect(backToOriginal.shape, equals(tPiece.shape));
    });
  });
}
