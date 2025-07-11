import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/tetromino.dart';
import '../constants/game_constants.dart';

class GameLogic extends ChangeNotifier {
  late List<List<Color?>> board;
  late Timer gameTimer;

  // Current piece
  Tetromino? currentPiece;
  int currentX = 0;
  int currentY = 0;

  // Next piece
  Tetromino? nextPiece;

  // Hold piece
  Tetromino? heldPiece;
  bool canHold = true; // Prevents holding multiple times per piece

  // Game state
  bool isGameRunning = false;
  bool isGameOver = false;
  bool isSlamming = false; // Track if piece is currently slamming down
  bool isNewPieceGracePeriod =
      false; // Prevent immediate input after new piece spawns
  Timer? gracePeriodTimer;
  int score = 0;
  int level = 1;
  int linesCleared = 0;
  int dropSpeed = GameConstants.initialDropSpeed;

  // Line clearing animation
  List<int> clearingLines = [];
  bool isAnimatingClear = false;
  Timer? clearAnimationTimer;

  // Trail animation for hard drop
  List<Map<String, dynamic>> trailBlocks = [];
  bool isAnimatingTrail = false;
  Timer? trailAnimationTimer;

  GameLogic() {
    initializeBoard();
  }

  void initializeBoard() {
    board = List.generate(
      GameConstants.boardHeight + GameConstants.previewRows,
      (index) => List.generate(GameConstants.boardWidth, (index) => null),
    );
  }

  void startGame() {
    isGameRunning = true;
    isGameOver = false;
    score = 0;
    level = 1;
    linesCleared = 0;
    dropSpeed = GameConstants.initialDropSpeed;
    heldPiece = null;
    canHold = true;

    initializeBoard();
    spawnNewPiece();
    startGameTimer();
    notifyListeners();
  }

  void startGameTimer() {
    gameTimer = Timer.periodic(Duration(milliseconds: dropSpeed), (timer) {
      if (isGameRunning && !isGameOver) {
        movePieceDown();
      }
    });
  }

  void spawnNewPiece() {
    nextPiece ??= Tetromino.random();

    currentPiece = nextPiece;
    nextPiece = Tetromino.random();
    currentX = GameConstants.boardWidth ~/ 2 - 1;
    currentY = GameConstants.previewRows;

    // Reset slamming flag for new piece
    isSlamming = false;

    // Start grace period to prevent immediate input
    _startNewPieceGracePeriod();

    // Check for game over
    if (!canPlacePiece(currentX, currentY, currentPiece!)) {
      isGameOver = true;
      isGameRunning = false;
      gameTimer.cancel();
      notifyListeners();
    }
  }

  bool canPlacePiece(int x, int y, Tetromino piece) {
    for (int row = 0; row < piece.shape.length; row++) {
      for (int col = 0; col < piece.shape[row].length; col++) {
        if (piece.shape[row][col] == 1) {
          int newX = x + col;
          int newY = y + row;

          if (newX < 0 ||
              newX >= GameConstants.boardWidth ||
              newY >= GameConstants.boardHeight + GameConstants.previewRows) {
            return false;
          }

          if (newY >= 0 && board[newY][newX] != null) {
            return false;
          }
        }
      }
    }
    return true;
  }

  void placePiece() {
    if (currentPiece == null) return;

    for (int row = 0; row < currentPiece!.shape.length; row++) {
      for (int col = 0; col < currentPiece!.shape[row].length; col++) {
        if (currentPiece!.shape[row][col] == 1) {
          int newX = currentX + col;
          int newY = currentY + row;

          if (newY >= 0 &&
              newY < GameConstants.boardHeight + GameConstants.previewRows &&
              newX >= 0 &&
              newX < GameConstants.boardWidth) {
            board[newY][newX] = currentPiece!.color;
          }
        }
      }
    }

    clearLines();
    canHold = true; // Allow holding the next piece
    spawnNewPiece();
  }

  void clearLines() {
    if (isAnimatingClear) return; // Don't clear lines while animating

    List<int> fullLines = [];

    // Find all full lines
    for (int row = GameConstants.boardHeight + GameConstants.previewRows - 1;
        row >= GameConstants.previewRows;
        row--) {
      bool isLineFull = true;
      for (int col = 0; col < GameConstants.boardWidth; col++) {
        if (board[row][col] == null) {
          isLineFull = false;
          break;
        }
      }

      if (isLineFull) {
        fullLines.add(row);
      }
    }

    if (fullLines.isNotEmpty) {
      // Start the clearing animation
      clearingLines = fullLines;
      isAnimatingClear = true;

      // Pause the game timer during animation
      gameTimer.cancel();

      // Start the glow and disappear animation
      _startClearAnimation();
    }
  }

  void _startClearAnimation() {
    // Single animation duration to match the widget animation
    clearAnimationTimer = Timer(const Duration(milliseconds: 350), () {
      // Animation complete - actually remove the lines
      _completeClearAnimation();
    });

    // Trigger immediate update to start the animation
    notifyListeners();
  }

  void _completeClearAnimation() {
    int clearedLinesCount = clearingLines.length;

    // Remove the cleared lines from the board
    for (int row in clearingLines.reversed) {
      board.removeAt(row);
      // Add empty line at the top
      board.insert(
        GameConstants.previewRows,
        List.generate(GameConstants.boardWidth, (index) => null),
      );
    }

    // Update game state
    linesCleared += clearedLinesCount;
    score += clearedLinesCount * GameConstants.pointsPerLine * level;
    level = (linesCleared ~/ GameConstants.linesPerLevel) + 1;
    dropSpeed = max(
      GameConstants.minDropSpeed,
      GameConstants.initialDropSpeed -
          (level - 1) * GameConstants.speedIncrement,
    );

    // Reset animation state
    clearingLines.clear();
    isAnimatingClear = false;
    clearAnimationTimer?.cancel();
    clearAnimationTimer = null;

    // Restart game timer with new speed
    startGameTimer();
    notifyListeners();
  }

  void movePieceDown() {
    // Prevent downward movement during grace period
    if (isNewPieceGracePeriod) return;

    if (canPlacePiece(currentX, currentY + 1, currentPiece!)) {
      currentY++;
      notifyListeners();
    } else {
      placePiece();
    }
  }

  void movePieceLeft() {
    // Prevent horizontal movement during slam
    if (isSlamming) return;

    if (canPlacePiece(currentX - 1, currentY, currentPiece!)) {
      currentX--;
      notifyListeners();
    }
  }

  void movePieceRight() {
    // Prevent horizontal movement during slam
    if (isSlamming) return;

    if (canPlacePiece(currentX + 1, currentY, currentPiece!)) {
      currentX++;
      notifyListeners();
    }
  }

  void rotatePiece() {
    rotatePieceRight();
  }

  void rotatePieceRight() {
    if (currentPiece == null) return;

    Tetromino rotatedPiece = currentPiece!.rotateRight();

    // Try wall kicks - test different positions to see if rotation is possible
    List<List<int>> wallKickOffsets = [
      [0, 0], // Try current position first
      [-1, 0], // Try one left
      [1, 0], // Try one right
      [-2, 0], // Try two left
      [2, 0], // Try two right
      [0, -1], // Try one up
      [-1, -1], // Try one left and up
      [1, -1], // Try one right and up
    ];

    for (List<int> offset in wallKickOffsets) {
      int testX = currentX + offset[0];
      int testY = currentY + offset[1];

      if (canPlacePiece(testX, testY, rotatedPiece)) {
        currentPiece = rotatedPiece;
        currentX = testX;
        currentY = testY;
        notifyListeners();
        return;
      }
    }
    // If no wall kick worked, rotation fails silently
  }

  void rotatePieceLeft() {
    if (currentPiece == null) return;

    Tetromino rotatedPiece = currentPiece!.rotateLeft();

    // Try wall kicks - test different positions to see if rotation is possible
    List<List<int>> wallKickOffsets = [
      [0, 0], // Try current position first
      [-1, 0], // Try one left
      [1, 0], // Try one right
      [-2, 0], // Try two left
      [2, 0], // Try two right
      [0, -1], // Try one up
      [-1, -1], // Try one left and up
      [1, -1], // Try one right and up
    ];

    for (List<int> offset in wallKickOffsets) {
      int testX = currentX + offset[0];
      int testY = currentY + offset[1];

      if (canPlacePiece(testX, testY, rotatedPiece)) {
        currentPiece = rotatedPiece;
        currentX = testX;
        currentY = testY;
        notifyListeners();
        return;
      }
    }
    // If no wall kick worked, rotation fails silently
  }

  void dropPiece() {
    if (currentPiece == null) return;

    // Prevent hard drop during grace period
    if (isNewPieceGracePeriod) return;

    // Set slamming flag to lock horizontal position
    isSlamming = true;

    // Store the starting position for trail animation
    int startY = currentY;

    // Calculate the final position
    while (canPlacePiece(currentX, currentY + 1, currentPiece!)) {
      currentY++;
    }

    // Create trail animation if the piece moved more than 1 row
    if (currentY > startY + 1) {
      _createTrailAnimation(startY, currentY);
    }

    notifyListeners();
    placePiece();
  }

  void _createTrailAnimation(int startY, int endY) {
    if (currentPiece == null) return;

    // Clear any existing trail
    trailBlocks.clear();

    // Create trail blocks for each position the piece passed through
    // Only create trail for the last few positions to make it more visible
    int trailLength = (endY - startY).clamp(3, 8); // Limit trail length
    int trailStart = (endY - trailLength).clamp(startY, endY);

    for (int y = trailStart; y < endY; y++) {
      for (int row = 0; row < currentPiece!.shape.length; row++) {
        for (int col = 0; col < currentPiece!.shape[row].length; col++) {
          if (currentPiece!.shape[row][col] == 1) {
            int newX = currentX + col;
            int newY = y + row;

            if (newY >= GameConstants.previewRows &&
                newY < GameConstants.boardHeight + GameConstants.previewRows &&
                newX >= 0 &&
                newX < GameConstants.boardWidth) {
              double intensity = (y - trailStart) / trailLength; // 0.0 to 1.0
              trailBlocks.add({
                'x': newX,
                'y': newY,
                'color': currentPiece!.color,
                'intensity': intensity, // How bright this trail block should be
              });
            }
          }
        }
      }
    }

    // Start trail animation
    if (trailBlocks.isNotEmpty) {
      isAnimatingTrail = true;
      _startTrailAnimation();
    }
  }

  void _startTrailAnimation() {
    // Trail animation duration - quick and snappy
    trailAnimationTimer = Timer(const Duration(milliseconds: 200), () {
      // Animation complete - clear the trail
      trailBlocks.clear();
      isAnimatingTrail = false;
      trailAnimationTimer?.cancel();
      trailAnimationTimer = null;
      notifyListeners();
    });

    // Trigger immediate update to start the animation
    notifyListeners();
  }

  void _startNewPieceGracePeriod() {
    // Cancel any existing grace period timer
    gracePeriodTimer?.cancel();

    // Set grace period flag
    isNewPieceGracePeriod = true;

    // Start grace period timer - short delay to prevent accidental input
    gracePeriodTimer = Timer(const Duration(milliseconds: 200), () {
      isNewPieceGracePeriod = false;
      gracePeriodTimer = null;
    });
  }

  void holdPiece() {
    if (!canHold || currentPiece == null) return;

    if (heldPiece == null) {
      // First time holding - store current piece and spawn next
      heldPiece = currentPiece;
      spawnNewPiece();
    } else {
      // Swap current piece with held piece
      Tetromino temp = currentPiece!;
      currentPiece = heldPiece;
      heldPiece = temp;

      // Reset position for the swapped piece
      currentX = GameConstants.boardWidth ~/ 2 - 1;
      currentY = GameConstants.previewRows;

      // Check if the swapped piece can be placed
      if (!canPlacePiece(currentX, currentY, currentPiece!)) {
        // If it can't be placed, game over
        isGameOver = true;
        isGameRunning = false;
        gameTimer.cancel();
      }
    }

    canHold = false; // Prevent holding again until next piece
    notifyListeners();
  }

  int calculateGhostPieceY() {
    if (currentPiece == null) return currentY;

    int ghostY = currentY;
    while (canPlacePiece(currentX, ghostY + 1, currentPiece!)) {
      ghostY++;
    }
    return ghostY;
  }

  List<List<Color?>> getBoardWithCurrentPiece() {
    List<List<Color?>> displayBoard = List.generate(
      GameConstants.boardHeight + GameConstants.previewRows,
      (row) =>
          List.generate(GameConstants.boardWidth, (col) => board[row][col]),
    );

    if (currentPiece != null) {
      // First, draw the ghost piece (shadow)
      int ghostY = calculateGhostPieceY();
      if (ghostY != currentY) {
        // Only show ghost if it's different from current position
        for (int row = 0; row < currentPiece!.shape.length; row++) {
          for (int col = 0; col < currentPiece!.shape[row].length; col++) {
            if (currentPiece!.shape[row][col] == 1) {
              int newX = currentX + col;
              int newY = ghostY + row;

              if (newY >= 0 &&
                  newY <
                      GameConstants.boardHeight + GameConstants.previewRows &&
                  newX >= 0 &&
                  newX < GameConstants.boardWidth &&
                  displayBoard[newY][newX] == null) {
                // Use light blue color for ghost piece
                displayBoard[newY][newX] = GameConstants.ghostPieceColor;
              }
            }
          }
        }
      }

      // Then, draw the current piece (on top of ghost)
      for (int row = 0; row < currentPiece!.shape.length; row++) {
        for (int col = 0; col < currentPiece!.shape[row].length; col++) {
          if (currentPiece!.shape[row][col] == 1) {
            int newX = currentX + col;
            int newY = currentY + row;

            if (newY >= 0 &&
                newY < GameConstants.boardHeight + GameConstants.previewRows &&
                newX >= 0 &&
                newX < GameConstants.boardWidth) {
              displayBoard[newY][newX] = currentPiece!.color;
            }
          }
        }
      }
    }

    return displayBoard;
  }

  bool isLineClearingAnimation(int row) {
    return clearingLines.contains(row);
  }

  Map<String, dynamic>? getTrailBlock(int x, int y) {
    if (!isAnimatingTrail) return null;

    for (var block in trailBlocks) {
      if (block['x'] == x && block['y'] == y) {
        return block;
      }
    }
    return null;
  }

  @override
  void dispose() {
    gameTimer.cancel();
    clearAnimationTimer?.cancel();
    trailAnimationTimer?.cancel();
    gracePeriodTimer?.cancel();
    super.dispose();
  }
}
