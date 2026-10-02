import 'package:block_drop/constants/game_constants.dart';
import 'package:block_drop/game/game_logic.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:block_drop/widgets/game_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('four-line clear avoids per-cell opacity layers', (tester) async {
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

    final totalRows = GameConstants.boardHeight + GameConstants.previewRows;
    for (var row = totalRows - 4; row < totalRows; row++) {
      for (var col = 0; col < GameConstants.boardWidth; col++) {
        gameLogic.board[row][col] = Colors.red;
      }
    }

    gameLogic.clearLines();
    await tester.pump(const Duration(milliseconds: 100));

    expect(gameLogic.clearingLines, hasLength(4));
    expect(find.byType(Opacity), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox.shrink());
    gameLogic.dispose();
  });

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
    expect(
      find.bySemanticsLabel('2-line combo clear effect'),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 400));
    fillBottomRow();
    gameLogic.clearLines();
    await tester.pump();

    expect(gameLogic.lineClearStreak, 2);
    expect(find.bySemanticsLabel('2-line combo clear effect'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox.shrink());
    gameLogic.dispose();
  });

  testWidgets('left-half tap calls left rotation only', (tester) async {
    final gameLogic = GameLogic();
    gameLogic.startGame();
    var leftTaps = 0;
    var rightTaps = 0;

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
              onLeftTap: () => leftTaps++,
              onRightTap: () => rightTaps++,
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byType(GameBoard));
    await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.center.dy));
    await tester.pump();

    expect(leftTaps, 1);
    expect(rightTaps, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    gameLogic.dispose();
  });

  testWidgets('right-half tap calls right rotation only', (tester) async {
    final gameLogic = GameLogic();
    gameLogic.startGame();
    var leftTaps = 0;
    var rightTaps = 0;

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
              onLeftTap: () => leftTaps++,
              onRightTap: () => rightTaps++,
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byType(GameBoard));
    await tester.tapAt(Offset(rect.left + rect.width * 0.75, rect.center.dy));
    await tester.pump();

    expect(leftTaps, 0);
    expect(rightTaps, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    gameLogic.dispose();
  });
}
