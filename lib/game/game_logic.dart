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

  // Game state
  bool isGameRunning = false;
  bool isGameOver = false;
  int score = 0;
  int level = 1;
  int linesCleared = 0;
  int dropSpeed = GameConstants.initialDropSpeed;

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
    spawnNewPiece();
  }

  void clearLines() {
    int clearedLines = 0;

    for (
      int row = GameConstants.boardHeight + GameConstants.previewRows - 1;
      row >= GameConstants.previewRows;
      row--
    ) {
      bool isLineFull = true;
      for (int col = 0; col < GameConstants.boardWidth; col++) {
        if (board[row][col] == null) {
          isLineFull = false;
          break;
        }
      }

      if (isLineFull) {
        // Remove the full line
        board.removeAt(row);
        // Add empty line at the top
        board.insert(
          GameConstants.previewRows,
          List.generate(GameConstants.boardWidth, (index) => null),
        );
        clearedLines++;
        row++; // Check the same row again
      }
    }

    if (clearedLines > 0) {
      linesCleared += clearedLines;
      score += clearedLines * GameConstants.pointsPerLine * level;
      level = (linesCleared ~/ GameConstants.linesPerLevel) + 1;
      dropSpeed = max(
        GameConstants.minDropSpeed,
        GameConstants.initialDropSpeed -
            (level - 1) * GameConstants.speedIncrement,
      );

      // Restart timer with new speed
      gameTimer.cancel();
      startGameTimer();
      notifyListeners();
    }
  }

  void movePieceDown() {
    if (canPlacePiece(currentX, currentY + 1, currentPiece!)) {
      currentY++;
      notifyListeners();
    } else {
      placePiece();
    }
  }

  void movePieceLeft() {
    if (canPlacePiece(currentX - 1, currentY, currentPiece!)) {
      currentX--;
      notifyListeners();
    }
  }

  void movePieceRight() {
    if (canPlacePiece(currentX + 1, currentY, currentPiece!)) {
      currentX++;
      notifyListeners();
    }
  }

  void rotatePiece() {
    if (currentPiece == null) return;

    Tetromino rotatedPiece = currentPiece!.rotate();
    if (canPlacePiece(currentX, currentY, rotatedPiece)) {
      currentPiece = rotatedPiece;
      notifyListeners();
    }
  }

  void dropPiece() {
    while (canPlacePiece(currentX, currentY + 1, currentPiece!)) {
      currentY++;
    }
    notifyListeners();
    placePiece();
  }

  List<List<Color?>> getBoardWithCurrentPiece() {
    List<List<Color?>> displayBoard = List.generate(
      GameConstants.boardHeight + GameConstants.previewRows,
      (row) =>
          List.generate(GameConstants.boardWidth, (col) => board[row][col]),
    );

    if (currentPiece != null) {
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

  @override
  void dispose() {
    gameTimer.cancel();
    super.dispose();
  }
}
