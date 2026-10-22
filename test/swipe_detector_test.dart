import 'package:block_drop/game/game_logic.dart';
import 'package:block_drop/models/tetromino.dart';
import 'package:block_drop/widgets/swipe_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('upward swipe hard-drops the active piece', (tester) async {
    final game = GameLogic(pieceBag: TetrominoBag(seed: 1));
    game.startGame();
    game.isNewPieceGracePeriod = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeDetector(
            gameLogic: game,
            moveThreshold: 30,
            fastSwipeVelocity: 500,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    await tester.fling(
      find.byType(SwipeDetector),
      const Offset(0, -180),
      900,
    );
    await tester.pump();

    expect(
      game.board.expand((row) => row).whereType<Color>(),
      isNotEmpty,
    );
    game.dispose();
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('a second finger touching down does not cause horizontal jumps',
      (tester) async {
    final game = GameLogic(pieceBag: TetrominoBag(seed: 1));
    game.startGame();
    game.isNewPieceGracePeriod = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeDetector(
            gameLogic: game,
            moveThreshold: 30,
            fastSwipeVelocity: 500,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final first = await tester.startGesture(const Offset(100, 300));
    await first.moveBy(const Offset(35, 0));
    await tester.pump();

    final xAfterFirstMove = game.currentX;

    // A second finger touches down far to the right (e.g. on the rotate
    // buttons) and drifts slightly. This must not translate into a large
    // horizontal jump of the piece.
    final second = await tester.startGesture(const Offset(700, 300));
    await second.moveBy(const Offset(5, 0));
    await tester.pump();

    expect(game.currentX - xAfterFirstMove, lessThanOrEqualTo(1));

    await first.up();
    await second.up();
    game.dispose();
    await tester.pump(const Duration(milliseconds: 250));
  });
}
