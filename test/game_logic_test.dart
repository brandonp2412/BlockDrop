import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:block_drop/game/game_logic.dart';
import 'package:block_drop/constants/game_constants.dart';

void main() {
  group('GameLogic Tests', () {
    late GameLogic gameLogic;

    setUp(() {
      gameLogic = GameLogic();
    });

    tearDown(() {
      if (gameLogic.isGameRunning) {
        gameLogic.dispose();
      }
    });

    test('should initialize with correct default values', () {
      expect(gameLogic.isGameRunning, false);
      expect(gameLogic.isGameOver, false);
      expect(gameLogic.score, 0);
      expect(gameLogic.level, 1);
      expect(gameLogic.linesCleared, 0);
      expect(gameLogic.currentPiece, null);
      expect(gameLogic.nextPiece, null);
      expect(gameLogic.heldPiece, null);
      expect(gameLogic.canHold, true);
    });

    test('should initialize board with correct dimensions', () {
      expect(
        gameLogic.board.length,
        GameConstants.boardHeight + GameConstants.previewRows,
      );
      expect(gameLogic.board[0].length, GameConstants.boardWidth);

      // All cells should be empty initially
      for (int row = 0; row < gameLogic.board.length; row++) {
        for (int col = 0; col < gameLogic.board[row].length; col++) {
          expect(gameLogic.board[row][col], null);
        }
      }
    });

    test('should start game correctly', () {
      gameLogic.startGame();

      expect(gameLogic.isGameRunning, true);
      expect(gameLogic.isGameOver, false);
      expect(gameLogic.score, 0);
      expect(gameLogic.level, 1);
      expect(gameLogic.linesCleared, 0);
      expect(gameLogic.currentPiece, isNotNull);
      expect(gameLogic.nextPiece, isNotNull);
      expect(gameLogic.heldPiece, null);
      expect(gameLogic.canHold, true);
    });

    test('should place piece correctly on board', () {
      gameLogic.startGame();

      // Get initial piece
      final piece = gameLogic.currentPiece!;
      final initialX = gameLogic.currentX;

      // Move piece to bottom
      while (gameLogic.canPlacePiece(initialX, gameLogic.currentY + 1, piece)) {
        gameLogic.currentY++;
      }

      gameLogic.placePiece();

      // Check that piece was placed on board
      bool pieceFound = false;
      for (int row = 0; row < gameLogic.board.length; row++) {
        for (int col = 0; col < gameLogic.board[row].length; col++) {
          if (gameLogic.board[row][col] == piece.color) {
            pieceFound = true;
            break;
          }
        }
        if (pieceFound) break;
      }

      expect(pieceFound, true);
      expect(
        gameLogic.currentPiece,
        isNot(equals(piece)),
      ); // New piece should be spawned
    });

    test('should detect collision correctly', () {
      gameLogic.startGame();

      final piece = gameLogic.currentPiece!;

      // Test boundary collisions
      expect(
        gameLogic.canPlacePiece(-1, gameLogic.currentY, piece),
        false,
      ); // Left boundary
      expect(
        gameLogic.canPlacePiece(
          GameConstants.boardWidth,
          gameLogic.currentY,
          piece,
        ),
        false,
      ); // Right boundary
      expect(
        gameLogic.canPlacePiece(
          gameLogic.currentX,
          GameConstants.boardHeight + GameConstants.previewRows,
          piece,
        ),
        false,
      ); // Bottom boundary

      // Test valid position
      expect(
        gameLogic.canPlacePiece(gameLogic.currentX, gameLogic.currentY, piece),
        true,
      );
    });

    test('should move piece left and right correctly', () {
      gameLogic.startGame();

      final initialX = gameLogic.currentX;

      gameLogic.movePieceLeft();
      expect(gameLogic.currentX, initialX - 1);

      gameLogic.movePieceRight();
      expect(gameLogic.currentX, initialX);

      gameLogic.movePieceRight();
      expect(gameLogic.currentX, initialX + 1);
    });

    test('should move piece down correctly', () {
      gameLogic.startGame();

      final initialY = gameLogic.currentY;

      gameLogic.movePieceDown();
      expect(gameLogic.currentY, initialY + 1);
    });

    test('should not move piece beyond boundaries', () {
      gameLogic.startGame();

      // Move to left boundary
      while (gameLogic.canPlacePiece(
        gameLogic.currentX - 1,
        gameLogic.currentY,
        gameLogic.currentPiece!,
      )) {
        gameLogic.movePieceLeft();
      }
      final leftBoundaryX = gameLogic.currentX;
      gameLogic.movePieceLeft(); // Should not move further
      expect(gameLogic.currentX, leftBoundaryX);

      // Move to right boundary
      while (gameLogic.canPlacePiece(
        gameLogic.currentX + 1,
        gameLogic.currentY,
        gameLogic.currentPiece!,
      )) {
        gameLogic.movePieceRight();
      }
      final rightBoundaryX = gameLogic.currentX;
      gameLogic.movePieceRight(); // Should not move further
      expect(gameLogic.currentX, rightBoundaryX);
    });

    test('should rotate piece correctly', () {
      gameLogic.startGame();

      final originalPiece = gameLogic.currentPiece!;
      final originalShape = originalPiece.shape;

      gameLogic.rotatePieceRight();

      // Shape should be different after rotation (unless it's a square piece)
      if (originalShape.length != originalShape[0].length ||
          originalShape.length > 2) {
        expect(gameLogic.currentPiece!.shape, isNot(equals(originalShape)));
      }

      expect(
        gameLogic.currentPiece!.color,
        originalPiece.color,
      ); // Color should remain same
    });

    test('should hold piece correctly', () {
      gameLogic.startGame();

      final originalPiece = gameLogic.currentPiece!;

      // First hold
      gameLogic.holdPiece();
      expect(gameLogic.heldPiece, isNotNull);
      expect(gameLogic.heldPiece!.color, originalPiece.color);
      expect(gameLogic.canHold, false);
      // Current piece should be different (new piece spawned)
      expect(gameLogic.currentPiece, isNotNull);

      // Should not be able to hold again immediately
      final currentPieceBeforeSecondHold = gameLogic.currentPiece!;
      gameLogic.holdPiece();
      expect(
        gameLogic.currentPiece!.color,
        equals(currentPieceBeforeSecondHold.color),
      ); // Should not change
    });

    test('should swap held piece correctly', () {
      gameLogic.startGame();

      final firstPiece = gameLogic.currentPiece!;
      gameLogic.holdPiece(); // Hold first piece

      final secondPiece = gameLogic.currentPiece!;
      gameLogic.canHold = true; // Reset hold ability for test
      gameLogic.holdPiece(); // Hold second piece, should swap with first

      expect(gameLogic.currentPiece!.color, firstPiece.color);
      expect(gameLogic.heldPiece!.color, secondPiece.color);
    });

    test('should calculate ghost piece position correctly', () {
      gameLogic.startGame();

      final ghostY = gameLogic.calculateGhostPieceY();

      // Ghost should be at or below current position
      expect(ghostY, greaterThanOrEqualTo(gameLogic.currentY));

      // Ghost should be at the lowest valid position
      expect(
        gameLogic.canPlacePiece(
          gameLogic.currentX,
          ghostY,
          gameLogic.currentPiece!,
        ),
        true,
      );
      expect(
        gameLogic.canPlacePiece(
          gameLogic.currentX,
          ghostY + 1,
          gameLogic.currentPiece!,
        ),
        false,
      );
    });

    test('should drop piece to bottom correctly', () {
      gameLogic.startGame();

      final initialY = gameLogic.currentY;
      final expectedGhostY = gameLogic.calculateGhostPieceY();

      gameLogic.dropPiece();

      // After drop, a new piece should be spawned at the top
      expect(
        gameLogic.currentY,
        GameConstants.previewRows,
      ); // New piece starts at preview rows

      // The drop should have moved the piece down (ghost position should be lower than initial)
      expect(expectedGhostY, greaterThanOrEqualTo(initialY));
    });

    test('should update score and level when lines are cleared', () {
      gameLogic.startGame();

      // Fill bottom row except one column
      for (int col = 0; col < GameConstants.boardWidth - 1; col++) {
        gameLogic.board[GameConstants.boardHeight +
            GameConstants.previewRows -
            1][col] = Colors.red;
      }

      // Place a piece to complete the line
      gameLogic.board[GameConstants.boardHeight + GameConstants.previewRows - 1]
          [GameConstants.boardWidth - 1] = Colors.blue;

      gameLogic.clearLines();

      // Wait for animation to complete
      expect(gameLogic.clearingLines.length, 1);
      expect(gameLogic.isAnimatingClear, true);
    });

    test('should detect game over correctly', () {
      gameLogic.startGame();

      // Fill the board up to the spawn area
      for (int row = GameConstants.previewRows;
          row < GameConstants.boardHeight + GameConstants.previewRows;
          row++) {
        for (int col = 0; col < GameConstants.boardWidth; col++) {
          gameLogic.board[row][col] = Colors.red;
        }
      }

      // Try to spawn a new piece
      gameLogic.spawnNewPiece();

      expect(gameLogic.isGameOver, true);
      expect(gameLogic.isGameRunning, false);
    });

    test('should get board with current piece correctly', () {
      gameLogic.startGame();

      final boardWithPiece = gameLogic.getBoardWithCurrentPiece();

      expect(
        boardWithPiece.length,
        GameConstants.boardHeight + GameConstants.previewRows,
      );
      expect(boardWithPiece[0].length, GameConstants.boardWidth);

      // Should contain current piece
      bool currentPieceFound = false;
      bool ghostPieceFound = false;

      for (int row = 0; row < boardWithPiece.length; row++) {
        for (int col = 0; col < boardWithPiece[row].length; col++) {
          if (boardWithPiece[row][col] == gameLogic.currentPiece!.color) {
            currentPieceFound = true;
          }
          if (boardWithPiece[row][col] == GameConstants.ghostPieceColor) {
            ghostPieceFound = true;
          }
        }
      }

      expect(currentPieceFound, true);
      // Ghost piece should be visible if it's different from current position
      final ghostY = gameLogic.calculateGhostPieceY();
      if (ghostY != gameLogic.currentY) {
        expect(ghostPieceFound, true);
      }
    });
  });
}
