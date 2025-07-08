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

  // Gesture tracking constants - made less sensitive to prevent accidental actions
  static const double _moveThreshold =
      25.0; // Distance threshold for movement (increased)
  static const double _fastSwipeVelocity =
      1000.0; // Velocity threshold for hard drop (increased significantly)
  static const double _continuousSwipeVelocity =
      500.0; // Velocity for continuous movement (increased)
  static const double _rotationThreshold =
      20.0; // Separate threshold for rotation detection

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
            } else if (event is KeyRepeatEvent &&
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
                            GestureDetector(
                              child: Column(
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
                              onTap: () {
                                gameLogic.holdPiece();
                              },
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
                          gameLogic: gameLogic,
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
  DateTime _lastMoveTime = DateTime.now();
  final DateTime _gestureStartTime = DateTime.now();
  static const Duration _moveDelay = Duration(
    milliseconds: 150,
  ); // Increased delay
  static const Duration _minGestureDuration = Duration(
    milliseconds: 50,
  ); // Minimum time before registering movement
  final bool _hasMovedHorizontally = false;
  final bool _hasMovedVertically = false;
  final bool _isIntentionalGesture = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        // Reset tracking variables at start of gesture
        _totalDx = 0.0;
        _totalDy = 0.0;
        _lastMoveTime = DateTime.now();
      },
      onPanUpdate: (details) {
        if (!widget.gameLogic.isGameRunning || widget.gameLogic.isGameOver) {
          return;
        }

        // Accumulate total movement
        _totalDx += details.delta.dx;
        _totalDy += details.delta.dy;

        final now = DateTime.now();
        final timeSinceLastMove = now.difference(_lastMoveTime);

        // Determine if this is primarily a horizontal or vertical gesture
        final isHorizontalGesture = _totalDx.abs() > _totalDy.abs();
        final isPrimaryDirection =
            isHorizontalGesture
                ? _totalDx.abs() > _totalDy.abs() * 1.5
                : _totalDy.abs() > _totalDx.abs() * 1.5;

        // Only process movement if we have a clear directional intent
        if (isPrimaryDirection) {
          // Horizontal movement - more restrictive to prevent accidental moves
          if (isHorizontalGesture && _totalDx.abs() >= widget.moveThreshold) {
            if (_totalDx > 0) {
              widget.gameLogic.movePieceRight();
            } else {
              widget.gameLogic.movePieceLeft();
            }
            _totalDx = 0.0;
            _lastMoveTime = now;
          }
          // Continuous horizontal movement - even more restrictive
          else if (isHorizontalGesture &&
              _totalDx.abs() >= widget.moveThreshold * 0.7 &&
              timeSinceLastMove >= _moveDelay &&
              details.delta.dx.abs() > 3.0) {
            if (_totalDx > 0) {
              widget.gameLogic.movePieceRight();
            } else {
              widget.gameLogic.movePieceLeft();
            }
            _totalDx = 0.0;
            _lastMoveTime = now;
          }

          // Vertical movement - only downward
          if (!isHorizontalGesture && _totalDy >= widget.moveThreshold) {
            widget.gameLogic.movePieceDown();
            _totalDy = 0.0;
            _lastMoveTime = now;
          }
          // Continuous downward movement
          else if (!isHorizontalGesture &&
              _totalDy >= widget.moveThreshold * 0.7 &&
              timeSinceLastMove >= _moveDelay &&
              details.delta.dy > 3.0) {
            widget.gameLogic.movePieceDown();
            _totalDy = 0.0;
            _lastMoveTime = now;
          }
        }
      },
      onPanEnd: (details) {
        if (!widget.gameLogic.isGameRunning || widget.gameLogic.isGameOver) {
          return;
        }

        // Handle fast downward swipe for instant drop - much higher threshold
        if (details.velocity.pixelsPerSecond.dy > widget.fastSwipeVelocity &&
            details.velocity.pixelsPerSecond.dy >
                details.velocity.pixelsPerSecond.dx.abs() * 2) {
          widget.gameLogic.dropPiece();
        }
        // Handle fast horizontal swipes - higher threshold and more restrictive
        else if (details.velocity.pixelsPerSecond.dx.abs() > 600.0 &&
            details.velocity.pixelsPerSecond.dx.abs() >
                details.velocity.pixelsPerSecond.dy.abs() * 2) {
          final direction = details.velocity.pixelsPerSecond.dx > 0 ? 1 : -1;
          // Reduced extra moves to prevent over-movement
          final extraMoves =
              (details.velocity.pixelsPerSecond.dx.abs() / 1200.0)
                  .clamp(0.0, 2.0)
                  .round();
          for (int i = 0; i < extraMoves; i++) {
            if (direction > 0) {
              widget.gameLogic.movePieceRight();
            } else {
              widget.gameLogic.movePieceLeft();
            }
          }
        }

        // Reset tracking variables
        _totalDx = 0.0;
        _totalDy = 0.0;
      },
      child: widget.child,
    );
  }
}
