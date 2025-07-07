import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/game_logic.dart';
import '../widgets/game_board.dart';
import '../widgets/next_piece_display.dart';
import '../constants/game_constants.dart';

class TetrisGameScreen extends StatefulWidget {
  const TetrisGameScreen({super.key});

  @override
  State<TetrisGameScreen> createState() => _TetrisGameScreenState();
}

class _TetrisGameScreenState extends State<TetrisGameScreen> {
  late GameLogic gameLogic;

  @override
  void initState() {
    super.initState();
    gameLogic = GameLogic();
    gameLogic.addListener(_onGameStateChanged);
    gameLogic.startGame();
  }

  void _onGameStateChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    gameLogic.removeListener(_onGameStateChanged);
    gameLogic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                gameLogic.isGameRunning &&
                !gameLogic.isGameOver) {
              switch (event.logicalKey) {
                case LogicalKeyboardKey.arrowLeft:
                  gameLogic.movePieceLeft();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowRight:
                  gameLogic.movePieceRight();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowDown:
                  gameLogic.movePieceDown();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowUp:
                  gameLogic.rotatePiece();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.space:
                  gameLogic.dropPiece();
                  return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate the maximum height available for the game board
              double availableHeight =
                  constraints.maxHeight - 16; // Account for margins
              double availableWidth =
                  (constraints.maxWidth * 2 / 3) -
                  16; // 2/3 for game board, minus margins

              // Calculate the ideal size based on aspect ratio
              double idealWidth =
                  availableHeight *
                  (GameConstants.boardWidth / GameConstants.boardHeight);
              double idealHeight =
                  availableWidth *
                  (GameConstants.boardHeight / GameConstants.boardWidth);

              // Use the smaller dimension to ensure it fits
              double gameboardWidth, gameboardHeight;
              if (idealWidth <= availableWidth) {
                gameboardWidth = idealWidth;
                gameboardHeight = availableHeight;
              } else {
                gameboardWidth = availableWidth;
                gameboardHeight = idealHeight;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game board
                  Container(
                    width: (constraints.maxWidth * 2 / 3),
                    height: constraints.maxHeight,
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: Container(
                        width: gameboardWidth,
                        height: gameboardHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: GameBoard(
                          board: gameLogic.getBoardWithCurrentPiece(),
                          previewRows: GameConstants.previewRows,
                        ),
                      ),
                    ),
                  ),

                  // Side panel
                  Expanded(
                    child: Container(
                      height: constraints.maxHeight,
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Score
                            Text(
                              'Score: ${gameLogic.score}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Level: ${gameLogic.level}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lines: ${gameLogic.linesCleared}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Next piece
                            const Text(
                              'Next:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white),
                              ),
                              child:
                                  gameLogic.nextPiece != null
                                      ? NextPieceDisplay(
                                        piece: gameLogic.nextPiece!,
                                      )
                                      : null,
                            ),

                            const SizedBox(height: 24),

                            // Controls
                            const Text(
                              'Controls:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '← → Move\n↓ Soft drop\n↑ Rotate\nSpace Hard drop',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Game over / restart
                            if (gameLogic.isGameOver)
                              Column(
                                children: [
                                  const Text(
                                    'Game Over!',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: gameLogic.startGame,
                                    child: const Text('Restart'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
