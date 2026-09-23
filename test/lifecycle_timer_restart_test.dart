// Regression tests for "the piece stops falling after I go back to the app".
//
// On Android, backgrounding drives GameLogic.pauseGame() and returning drives
// GameLogic.resumeGame(). pauseGame() used to cancel the grace-period, line
// clear and trail timers without clearing their fields, so resumeGame()'s
// `timer == null` guards never fired: isNewPieceGracePeriod / isAnimatingClear
// stayed true forever and movePieceDown() early-returned on every gravity tick.
//
// These tests fail before the fix and pass after it.

import 'package:block_drop/constants/game_constants.dart';
import 'package:block_drop/game/game_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GameLogic game;

  setUp(() {
    game = GameLogic(lockDelay: const Duration(milliseconds: 60));
  });

  tearDown(() {
    game.gameTimer?.cancel();
    game.pauseGame();
    game.dispose();
  });

  group('pauseGame timer bookkeeping', () {
    test('clears every timer handle it cancels', () {
      game.startGame();
      expect(game.gameTimer, isNotNull);
      expect(game.gracePeriodTimer, isNotNull);

      game.pauseGame();

      expect(game.gameTimer, isNull);
      expect(game.gracePeriodTimer, isNull);
      expect(game.clearAnimationTimer, isNull);
      expect(game.trailAnimationTimer, isNull);
    });
  });

  group('spawn grace period across background/foreground', () {
    test('grace period ends after resume so the piece can fall', () async {
      game.startGame();
      expect(game.isNewPieceGracePeriod, isTrue);

      // AppLifecycleState.hidden -> AppLifecycleState.resumed
      game.pauseGame();
      game.resumeGame();
      expect(game.gracePeriodTimer, isNotNull,
          reason: 'resumeGame must restart the grace-period timer');

      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(game.isNewPieceGracePeriod, isFalse);

      final before = game.currentY;
      game.movePieceDown();
      expect(game.currentY, greaterThan(before));
    });

    test('hard drop is not permanently blocked after resume', () async {
      game.startGame();
      game.pauseGame();
      game.resumeGame();

      await Future<void>.delayed(const Duration(milliseconds: 400));

      // dropPiece() locks the piece and immediately spawns a new one at the
      // same spawn row, so currentY is not a useful before/after signal here.
      // Check that the piece actually landed on the board instead.
      game.dropPiece();
      final anythingSettled =
          game.board.any((row) => row.any((cell) => cell != null));
      expect(anythingSettled, isTrue,
          reason: 'a blocked hard drop leaves the board untouched');
    });

    test('gravity keeps moving the piece after resume', () async {
      game.startGame();
      game.pauseGame();
      game.resumeGame();

      final before = game.currentY;
      await Future<void>.delayed(
        Duration(milliseconds: game.dropSpeed * 2 + 400),
      );

      expect(game.currentY, greaterThan(before),
          reason: 'the gravity timer ticks but movePieceDown() was a no-op');
    });
  });

  group('line clear animation across background/foreground', () {
    test('clear completes and the board is compacted', () async {
      game.startGame();

      final lastRow = GameConstants.boardHeight + GameConstants.previewRows - 1;
      for (var col = 0; col < GameConstants.boardWidth; col++) {
        game.board[lastRow][col] = Colors.red;
      }

      game.clearLines();
      expect(game.isAnimatingClear, isTrue);
      expect(game.clearAnimationTimer, isNotNull);

      game.pauseGame();
      expect(game.clearAnimationTimer, isNull);

      game.resumeGame();
      expect(game.clearAnimationTimer, isNotNull,
          reason: 'resumeGame must restart the clear animation timer');

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(game.isAnimatingClear, isFalse);
      expect(game.linesCleared, 1);
      expect(game.board[lastRow].every((cell) => cell == null), isTrue);
    });
  });

  group('hard drop trail across background/foreground', () {
    test('trail animation finishes after resume', () async {
      game.startGame();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      game.dropPiece();
      expect(game.isAnimatingTrail, isTrue);

      game.pauseGame();
      game.resumeGame();

      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(game.isAnimatingTrail, isFalse);
      expect(game.trailBlocks, isEmpty);
    });
  });

  group('lock delay across background/foreground', () {
    test(
        'a grounded piece still locks if the deadline passed in the '
        'background', () async {
      game.startGame();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      while (game.canPlacePiece(
        game.currentX,
        game.currentY + 1,
        game.currentPiece!,
      )) {
        game.movePieceDown();
      }
      game.movePieceDown(); // grounded: arms the lock delay
      expect(game.isLockDelayActive, isTrue);

      game.pauseGame();
      // The lock deadline expires while the app is in the background.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      game.resumeGame();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final anythingSettled =
          game.board.any((row) => row.any((cell) => cell != null));
      expect(anythingSettled, isTrue,
          reason: 'the piece should lock immediately on resume');
    });
  });
}
