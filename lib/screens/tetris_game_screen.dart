import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/game_logic.dart';
import '../widgets/game_board.dart';
import '../widgets/next_piece_display.dart';
import '../widgets/hold_piece_display.dart';
import '../constants/game_constants.dart';

class TetrisGameScreen extends StatefulWidget {
  const TetrisGameScreen({super.key});

  @override
  State<TetrisGameScreen> createState() => _TetrisGameScreenState();
}

class _TetrisGameScreenState extends State<TetrisGameScreen> {
  late GameLogic gameLogic;

  // Gesture tracking constants
  static const double _moveThreshold = 30.0; // Distance threshold for movement
  static const double _fastSwipeVelocity =
      800.0; // Velocity threshold for hard drop

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
                case LogicalKeyboardKey.keyC:
                  gameLogic.holdPiece();
                  return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: _SwipeDetector(
            gameLogic: gameLogic,
            moveThreshold: _moveThreshold,
            fastSwipeVelocity: _fastSwipeVelocity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate space needed for UI elements
                double scoreHeight = 58; // Score section height
                double nextPieceHeight = 127; // Next piece section height
                double spacingHeight = 32; // SizedBox spacing
                double gameOverHeight =
                    gameLogic.isGameOver ? 80 : 0; // Game over section
                double totalUIHeight =
                    scoreHeight +
                    nextPieceHeight +
                    spacingHeight +
                    gameOverHeight;

                // Calculate the maximum height available for the game board
                double availableHeight = (constraints.maxHeight -
                        totalUIHeight -
                        32)
                    .clamp(100.0, double.infinity); // Extra padding for safety
                double availableWidth = constraints.maxWidth - 32;

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
                  gameboardWidth = idealWidth.clamp(100.0, double.infinity);
                  gameboardHeight = availableHeight.clamp(
                    100.0,
                    double.infinity,
                  );
                } else {
                  gameboardWidth = availableWidth.clamp(100.0, double.infinity);
                  gameboardHeight = idealHeight.clamp(100.0, double.infinity);
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Score section
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              'Score: ${gameLogic.score}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Level: ${gameLogic.level}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Lines: ${gameLogic.linesCleared}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Hold and Next pieces
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Hold piece
                            Column(
                              children: [
                                const Text(
                                  'Hold:',
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
                                  child: HoldPieceDisplay(
                                    piece: gameLogic.heldPiece,
                                  ),
                                ),
                              ],
                            ),
                            // Next piece
                            Column(
                              children: [
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
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Game board
                      Container(
                        width: gameboardWidth,
                        height: gameboardHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: GameBoard(
                          board: gameLogic.getBoardWithCurrentPiece(),
                          previewRows: GameConstants.previewRows,
                          onLeftTap: () {
                            if (gameLogic.isGameRunning &&
                                !gameLogic.isGameOver) {
                              gameLogic.rotatePieceLeft();
                            }
                          },
                          onRightTap: () {
                            if (gameLogic.isGameRunning &&
                                !gameLogic.isGameOver) {
                              gameLogic.rotatePieceRight();
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Game over / restart
                      if (gameLogic.isGameOver)
                        Column(
                          children: [
                            const Text(
                              'Game Over!',
                              style: TextStyle(color: Colors.red, fontSize: 20),
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeDetector extends StatefulWidget {
  final GameLogic gameLogic;
  final double moveThreshold;
  final double fastSwipeVelocity;
  final Widget child;

  const _SwipeDetector({
    required this.gameLogic,
    required this.moveThreshold,
    required this.fastSwipeVelocity,
    required this.child,
  });

  @override
  State<_SwipeDetector> createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<_SwipeDetector> {
  double _totalDx = 0.0;
  double _totalDy = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (TapDownDetails details) {
        if (!widget.gameLogic.isGameRunning || widget.gameLogic.isGameOver) {
          return;
        }

        // Get the screen width to determine left vs right tap
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Size size = renderBox.size;
        final Offset localPosition = details.localPosition;

        // Determine if tap was on left or right side of screen
        if (localPosition.dx < size.width / 2) {
          // Left side tap - rotate left
          widget.gameLogic.rotatePieceLeft();
        } else {
          // Right side tap - rotate right
          widget.gameLogic.rotatePieceRight();
        }
      },
      onPanStart: (details) {
        // Reset tracking variables at start of gesture
        _totalDx = 0.0;
        _totalDy = 0.0;
      },
      onPanUpdate: (details) {
        if (!widget.gameLogic.isGameRunning || widget.gameLogic.isGameOver) {
          return;
        }

        // Accumulate total movement
        _totalDx += details.delta.dx;
        _totalDy += details.delta.dy;

        // Check for horizontal movement threshold
        if (_totalDx.abs() >= widget.moveThreshold) {
          if (_totalDx > 0) {
            // Move right
            widget.gameLogic.movePieceRight();
          } else {
            // Move left
            widget.gameLogic.movePieceLeft();
          }
          _totalDx = 0.0; // Reset horizontal tracking
        }

        // Check for vertical movement threshold
        if (_totalDy >= widget.moveThreshold) {
          // Move down
          widget.gameLogic.movePieceDown();
          _totalDy = 0.0; // Reset vertical tracking
        }
      },
      onPanEnd: (details) {
        if (!widget.gameLogic.isGameRunning || widget.gameLogic.isGameOver) {
          return;
        }

        // Handle fast downward swipe for instant drop
        if (details.velocity.pixelsPerSecond.dy > widget.fastSwipeVelocity) {
          widget.gameLogic.dropPiece();
        }

        // Reset tracking variables
        _totalDx = 0.0;
        _totalDy = 0.0;
      },
      child: widget.child,
    );
  }
}
