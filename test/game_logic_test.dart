import 'package:block_drop/constants/game_constants.dart';
import 'package:block_drop/game/game_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameLogic Tests', () {
    late GameLogic gameLogic;

    setUp(() {
      gameLogic = GameLogic();
    });

    tearDown(() {
      gameLogic.dispose();
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

      // Wait for grace period to end
      gameLogic.isNewPieceGracePeriod = false;

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

    test('dropPiece should be blocked during grace period', () {
      gameLogic.startGame();

      // Grace period is always active immediately after a piece spawns
      expect(gameLogic.isNewPieceGracePeriod, true);

      gameLogic.dropPiece(); // Should return early without placing anything

      // The board should still be empty — no blocks placed
      bool boardHasPlacedBlocks =
          gameLogic.board.any((row) => row.any((cell) => cell != null));
      expect(boardHasPlacedBlocks, false,
          reason:
              'Hard drop during grace period must not place the piece on the board');
    });

    test('should start line clear animation when a full row is detected', () {
      gameLogic.startGame();

      // Fill the bottom row completely
      final bottomRow =
          GameConstants.boardHeight + GameConstants.previewRows - 1;
      for (int col = 0; col < GameConstants.boardWidth; col++) {
        gameLogic.board[bottomRow][col] = Colors.red;
      }

      gameLogic.clearLines();

      expect(gameLogic.clearingLines.length, 1);
      expect(gameLogic.isAnimatingClear, true);
    });

    test('should update score correctly after single line clear', () async {
      gameLogic.startGame();

      final bottomRow =
          GameConstants.boardHeight + GameConstants.previewRows - 1;
      for (int col = 0; col < GameConstants.boardWidth; col++) {
        gameLogic.board[bottomRow][col] = Colors.red;
      }

      gameLogic.clearLines();
      // Wait for the 350 ms clear animation timer to fire
      await Future.delayed(const Duration(milliseconds: 400));

      expect(gameLogic.score, GameConstants.lineClearScores[1] * 1); // 100
      expect(gameLogic.linesCleared, 1);
      expect(gameLogic.isAnimatingClear, false);
    });

    test('should award full TETRIS bonus for clearing 4 lines at once',
        () async {
      gameLogic.startGame();

      final totalRows = GameConstants.boardHeight + GameConstants.previewRows;
      for (int row = totalRows - 4; row < totalRows; row++) {
        for (int col = 0; col < GameConstants.boardWidth; col++) {
          gameLogic.board[row][col] = Colors.red;
        }
      }

      gameLogic.clearLines();
      await Future.delayed(const Duration(milliseconds: 400));

      expect(gameLogic.score, GameConstants.lineClearScores[4] * 1); // 800
      expect(gameLogic.linesCleared, 4);
      expect(gameLogic.clearBonusLabel, 'TETRIS!');
    });

    test('should increase level after clearing linesPerLevel lines', () async {
      gameLogic.startGame();

      // Fill exactly linesPerLevel full rows
      final totalRows = GameConstants.boardHeight + GameConstants.previewRows;
      for (int row = totalRows - GameConstants.linesPerLevel;
          row < totalRows;
          row++) {
        for (int col = 0; col < GameConstants.boardWidth; col++) {
          gameLogic.board[row][col] = Colors.red;
        }
      }

      gameLogic.clearLines();
      await Future.delayed(const Duration(milliseconds: 400));

      expect(gameLogic.linesCleared, GameConstants.linesPerLevel);
      expect(gameLogic.level, 2);
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

    test('should pause and resume game correctly', () {
      gameLogic.startGame();
      expect(gameLogic.isPaused, false);
      expect(gameLogic.isGameRunning, true);

      gameLogic.pauseGame();
      expect(gameLogic.isPaused, true);
      expect(gameLogic.isGameRunning, true); // still running, just paused
      expect(gameLogic.isGameOver, false);

      gameLogic.resumeGame();
      expect(gameLogic.isPaused, false);
      expect(gameLogic.isGameRunning, true);
    });

    test('pauseGame should be idempotent', () {
      gameLogic.startGame();
      gameLogic.pauseGame();
      gameLogic.pauseGame(); // second call should be a no-op
      expect(gameLogic.isPaused, true);
    });

    test('should receive garbage rows from opponent', () {
      gameLogic.startGame();

      final totalRows = GameConstants.boardHeight + GameConstants.previewRows;
      // Board bottom should be empty initially
      expect(gameLogic.board[totalRows - 1][0], isNull);

      gameLogic.receiveGarbage(2);

      // Count filled vs gap cells in the bottom 2 rows
      int filledCells = 0;
      int gapCells = 0;
      for (int row = totalRows - 2; row < totalRows; row++) {
        for (int col = 0; col < GameConstants.boardWidth; col++) {
          if (gameLogic.board[row][col] != null) {
            filledCells++;
          } else {
            gapCells++;
          }
        }
      }

      // Each garbage row has exactly one gap column
      expect(filledCells, (GameConstants.boardWidth - 1) * 2);
      expect(gapCells, 2);
    });

    test('receiveGarbage should be a no-op when lines <= 0', () {
      gameLogic.startGame();
      final boardBefore =
          gameLogic.board.map((row) => List<Color?>.from(row)).toList();

      gameLogic.receiveGarbage(0);

      for (int row = 0; row < gameLogic.board.length; row++) {
        expect(gameLogic.board[row], equals(boardBefore[row]));
      }
    });

    test('should export board snapshot with correct dimensions', () {
      gameLogic.startGame();

      final snapshot = gameLogic.exportBoardSnapshot();

      // Snapshot covers only the visible board (no preview rows)
      expect(
        snapshot.length,
        GameConstants.boardWidth * GameConstants.boardHeight,
      );
      // All values must be valid palette indices
      expect(snapshot.every((cell) => cell >= 0 && cell <= 8), true);
    });

    test('exportBoardSnapshot should include the current piece', () {
      gameLogic.startGame();

      final snapshot = gameLogic.exportBoardSnapshot();

      // Current piece should appear somewhere in the snapshot as a non-zero index
      expect(snapshot.any((cell) => cell > 0), true);
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
