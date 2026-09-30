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
}
