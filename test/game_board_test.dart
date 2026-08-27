import 'package:block_drop/constants/game_constants.dart';
import 'package:block_drop/game/game_logic.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:block_drop/widgets/game_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('combo effects begin on the second consecutive line clear', (
    tester,
  ) async {
    final gameLogic = GameLogic();
    gameLogic.startGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 480,
            child: GameBoard(
              board: gameLogic.board,
              previewRows: GameConstants.previewRows,
              gameLogic: gameLogic,
              style: AppStyle.modern,
            ),
          ),
        ),
      ),
    );

    final bottomRow = GameConstants.boardHeight + GameConstants.previewRows - 1;

    void fillBottomRow() {
      for (int col = 0; col < GameConstants.boardWidth; col++) {
        gameLogic.board[bottomRow][col] = Colors.red;
      }
    }

    fillBottomRow();
    gameLogic.clearLines();
    await tester.pump();
    expect(find.byKey(const ValueKey('combo-clear-effects')), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    fillBottomRow();
    gameLogic.clearLines();
    await tester.pump();

    expect(gameLogic.lineClearStreak, 2);
    expect(
      find.byKey(const ValueKey('combo-clear-effects')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox.shrink());
    gameLogic.dispose();
  });
}
