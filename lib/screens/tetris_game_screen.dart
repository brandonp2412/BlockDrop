import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../audio/audio_service.dart';
import '../constants/game_constants.dart';
import '../game/game_logic.dart';
import '../settings/settings_provider.dart';
import '../widgets/game_board.dart';
import '../widgets/hold_piece_display.dart';
import '../widgets/next_piece_display.dart';
import 'settings_screen.dart';

class TetrisGameScreen extends StatefulWidget {
  final SettingsProvider settings;

  const TetrisGameScreen({super.key, required this.settings});

  @override
  State<TetrisGameScreen> createState() => _TetrisGameScreenState();
}

class _TetrisGameScreenState extends State<TetrisGameScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late GameLogic gameLogic;
  late AudioService _audioService;

  // Score popup animation
  late AnimationController _popupController;
  late Animation<double> _popupOpacity;
  late Animation<double> _popupOffset;
  String _popupLabel = '';
  int _popupDelta = 0;
  bool _gameOverModal = false;
  bool _isSettingsOpen = false;

  // Gesture tracking constants - made more sensitive for better horizontal movement
  static const double _moveThreshold =
      18.0; // Distance threshold for movement (reduced for more sensitivity)
  static const double _fastSwipeVelocity =
      1000.0; // Velocity threshold for hard drop (increased significantly)

  final formatter = NumberFormat.decimalPattern('en_US');

  @override
  void initState() {
    super.initState();
    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _popupOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 45),
    ]).animate(_popupController);
    _popupOffset = Tween<double>(begin: 0.0, end: -60.0).animate(
      CurvedAnimation(parent: _popupController, curve: Curves.easeOut),
    );

    _audioService = AudioService(
      musicEnabled: widget.settings.musicEnabled,
      sfxEnabled: widget.settings.sfxEnabled,
    );
    _audioService.init().then((_) => _audioService.startMusic());

    gameLogic = GameLogic();
    gameLogic.audioService = _audioService;
    gameLogic.addListener(_onGameStateChanged);
    gameLogic.startGame();

    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_onSettingsChanged);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    // Escape: open settings when none are open; otherwise let Navigator pop
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (!_gameOverModal && !_isSettingsOpen) {
        _openSettings();
        return true;
      } else if (!_gameOverModal && _isSettingsOpen) {
        Navigator.of(context).pop();
      }
      return false; // let Navigator handle closing the open screen
    }

    // Q shows quit confirmation (only when at the game screen)
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyQ) {
      if (!_gameOverModal && !_isSettingsOpen) _showQuitConfirmation();
      return true;
    }

    if (!gameLogic.isGameRunning ||
        gameLogic.isGameOver ||
        gameLogic.isPaused) {
      return false;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        gameLogic.movePieceLeft();
        return true;
      case LogicalKeyboardKey.arrowRight:
        gameLogic.movePieceRight();
        return true;
      case LogicalKeyboardKey.arrowDown:
        gameLogic.movePieceDown();
        return true;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyZ:
        if (event is KeyDownEvent) gameLogic.rotatePiece();
        return true;
      case LogicalKeyboardKey.keyX:
        if (event is KeyDownEvent) gameLogic.rotatePieceRight();
        return true;
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.select:
        if (event is KeyDownEvent) gameLogic.dropPiece();
        return true;
      case LogicalKeyboardKey.keyC:
      case LogicalKeyboardKey.mediaPlayPause:
        if (event is KeyDownEvent) gameLogic.holdPiece();
        return true;
    }
    return false;
  }

  Future<void> _showQuitConfirmation() async {
    final wasRunning =
        gameLogic.isGameRunning && !gameLogic.isGameOver && !gameLogic.isPaused;
    if (wasRunning) gameLogic.pauseGame();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Game?'),
        content: const Text('Your current progress will be lost.'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      gameLogic.startGame();
      if (widget.settings.musicEnabled) _audioService.startMusic();
    } else if (wasRunning) {
      gameLogic.resumeGame();
    }
  }

  void _onSettingsChanged() {
    _audioService.musicEnabled = widget.settings.musicEnabled;
    _audioService.sfxEnabled = widget.settings.sfxEnabled;
    if (widget.settings.musicEnabled) {
      _audioService.resumeMusic();
    } else {
      _audioService.pauseMusic();
    }
    setState(() {});
  }

  Future<void> _openSettings() async {
    if (_isSettingsOpen) return;
    _isSettingsOpen = true;

    final wasRunning =
        gameLogic.isGameRunning && !gameLogic.isGameOver && !gameLogic.isPaused;
    if (wasRunning) gameLogic.pauseGame();
    _audioService.pauseMusic();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settings: widget.settings,
          onRestart: () {
            gameLogic.startGame();
            if (widget.settings.musicEnabled) _audioService.startMusic();
          },
          onQuit: () {
            gameLogic.startGame();
            if (widget.settings.musicEnabled) _audioService.startMusic();
          },
        ),
      ),
    );

    _isSettingsOpen = false;

    if (mounted &&
        gameLogic.isGameRunning &&
        !gameLogic.isGameOver &&
        gameLogic.isPaused) {
      gameLogic.resumeGame();
    }
    if (mounted && widget.settings.musicEnabled) {
      _audioService.resumeMusic();
    }
  }

  BoxDecoration _pieceBoxDecoration(AppStyle style, ColorScheme cs) {
    switch (style) {
      case AppStyle.classic:
        return BoxDecoration(border: Border.all(color: cs.outline));
      case AppStyle.modern:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline, width: 1),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        );
      case AppStyle.bubbles:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.4),
            width: 2,
          ),
        );
      case AppStyle.neon:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.outlineVariant.withValues(alpha: 0.2),
              blurRadius: 6,
              spreadRadius: 0,
            ),
          ],
        );
      case AppStyle.retro:
        return BoxDecoration(border: Border.all(color: cs.outline, width: 2));
    }
  }

  BoxDecoration _boardDecoration(AppStyle style, ColorScheme cs) {
    switch (style) {
      case AppStyle.classic:
        return BoxDecoration(border: Border.all(color: cs.outline, width: 2));
      case AppStyle.modern:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline, width: 1),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case AppStyle.bubbles:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.4),
            width: 2,
          ),
        );
      case AppStyle.neon:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: cs.primary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.6),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        );
      case AppStyle.retro:
        return BoxDecoration(border: Border.all(color: cs.outline, width: 2));
    }
  }

  void _onGameStateChanged() {
    // Consume score popup event before setState
    if (gameLogic.clearBonusLabel.isNotEmpty) {
      _popupLabel = gameLogic.clearBonusLabel;
      _popupDelta = gameLogic.lastScoreDelta;
      gameLogic.consumeClearBonus();
      _popupController.forward(from: 0.0);
    }

    setState(() {});

    // Show game over modal when game ends
    if (gameLogic.isGameOver && mounted) {
      widget.settings.updateHighScore(gameLogic.score);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGameOverModal();
      });
    }
  }

  void _showGameOverModal() async {
    if (_gameOverModal) return;
    setState(() {
      _gameOverModal = true;
    });
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.red, width: 2),
          ),
          title: const Text(
            'Game Over!',
            style: TextStyle(
              color: Colors.red,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Final Score: ${formatter.format(gameLogic.score)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Level: ${gameLogic.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Lines Cleared: ${gameLogic.linesCleared}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  gameLogic.startGame();
                  if (widget.settings.musicEnabled) _audioService.startMusic();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Play Again',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
    setState(() {
      _gameOverModal = false;
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _popupController.dispose();
    widget.settings.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    gameLogic.removeListener(_onGameStateChanged);
    gameLogic.dispose();
    _audioService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is going to background or being minimized - pause the game
        if (gameLogic.isGameRunning &&
            !gameLogic.isGameOver &&
            !gameLogic.isPaused) {
          gameLogic.pauseGame();
          _audioService.pauseMusic();
        }
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground - resume the game
        if (gameLogic.isGameRunning &&
            !gameLogic.isGameOver &&
            gameLogic.isPaused) {
          gameLogic.resumeGame();
          _audioService.resumeMusic();
        }
        break;
      case AppLifecycleState.hidden:
        // App is hidden but still running - pause the game
        if (gameLogic.isGameRunning &&
            !gameLogic.isGameOver &&
            !gameLogic.isPaused) {
          gameLogic.pauseGame();
          _audioService.pauseMusic();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_gameOverModal || _isSettingsOpen) return;
        if (gameLogic.isGameRunning &&
            !gameLogic.isGameOver &&
            !gameLogic.isPaused &&
            gameLogic.canHold) {
          gameLogic.holdPiece();
        } else {
          _openSettings();
        }
      },
      child: Scaffold(
        body: SafeArea(
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
                double totalUIHeight =
                    scoreHeight + nextPieceHeight + spacingHeight;

                // Calculate the maximum height available for the game board
                double availableHeight = (constraints.maxHeight -
                        totalUIHeight -
                        32)
                    .clamp(100.0, double.infinity); // Extra padding for safety
                double availableWidth = constraints.maxWidth - 32;

                // Calculate the ideal size based on aspect ratio
                double idealWidth = availableHeight *
                    (GameConstants.boardWidth / GameConstants.boardHeight);
                double idealHeight = availableWidth *
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
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Score section
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Text(
                              'Score: ${formatter.format(gameLogic.score)}',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 18,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Level: ${gameLogic.level}',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 18,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Lines: ${gameLogic.linesCleared}',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 4),
                            ExcludeFocus(
                              child: IconButton(
                                icon: Icon(
                                  Icons.settings,
                                  color: cs.onSurfaceVariant,
                                ),
                                iconSize: 22,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _openSettings,
                              ),
                            ),
                            const SizedBox(width: 4),
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
                                  Text(
                                    'Hold:',
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: _pieceBoxDecoration(
                                      widget.settings.style,
                                      cs,
                                    ),
                                    child: HoldPieceDisplay(
                                      piece: gameLogic.heldPiece,
                                      style: widget.settings.style,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                if (gameLogic.isGameRunning &&
                                    !gameLogic.isGameOver &&
                                    !gameLogic.isPaused) {
                                  gameLogic.holdPiece();
                                }
                              },
                            ),
                            // Next piece
                            Column(
                              children: [
                                Text(
                                  'Next:',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: _pieceBoxDecoration(
                                    widget.settings.style,
                                    cs,
                                  ),
                                  child: gameLogic.nextPiece != null
                                      ? NextPieceDisplay(
                                          piece: gameLogic.nextPiece!,
                                          style: widget.settings.style,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Game board with score popup overlay
                      SizedBox(
                        width: gameboardWidth,
                        height: gameboardHeight,
                        child: Stack(
                          children: [
                            Container(
                              width: gameboardWidth,
                              height: gameboardHeight,
                              decoration: _boardDecoration(
                                widget.settings.style,
                                cs,
                              ),
                              child: GameBoard(
                                board: gameLogic.getBoardWithCurrentPiece(),
                                previewRows: GameConstants.previewRows,
                                gameLogic: gameLogic,
                                style: widget.settings.style,
                                onLeftTap: () {
                                  if (gameLogic.isGameRunning &&
                                      !gameLogic.isGameOver &&
                                      !gameLogic.isPaused) {
                                    gameLogic.rotatePieceLeft();
                                  }
                                },
                                onRightTap: () {
                                  if (gameLogic.isGameRunning &&
                                      !gameLogic.isGameOver &&
                                      !gameLogic.isPaused) {
                                    gameLogic.rotatePieceRight();
                                  }
                                },
                              ),
                            ),
                            // Score popup
                            AnimatedBuilder(
                              animation: _popupController,
                              builder: (context, _) {
                                if (_popupController.isDismissed) {
                                  return const SizedBox.shrink();
                                }
                                return Positioned(
                                  left: 0,
                                  right: 0,
                                  top: gameboardHeight / 2 + _popupOffset.value,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: _popupOpacity.value,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _popupLabel,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: _popupLabel
                                                      .startsWith('T-SPIN')
                                                  ? Colors.purple[200]
                                                  : (_popupLabel == 'TETRIS!'
                                                      ? Colors.amber
                                                      : Colors.white),
                                              fontSize: _popupLabel == 'TETRIS!'
                                                  ? 26
                                                  : 20,
                                              fontWeight: FontWeight.bold,
                                              shadows: const [
                                                Shadow(
                                                    blurRadius: 8,
                                                    color: Colors.black),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '+$_popupDelta',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              shadows: [
                                                Shadow(
                                                    blurRadius: 6,
                                                    color: Colors.black),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
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
  bool _directionLocked = false;
  bool _lockedHorizontal = false;
  static const Duration _moveDelay = Duration(
    milliseconds: 150,
  ); // Increased delay
  // Minimum movement to lock gesture direction
  static const double _lockThreshold = 10.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        // Reset tracking variables at start of gesture
        _totalDx = 0.0;
        _totalDy = 0.0;
        _directionLocked = false;
        _lockedHorizontal = false;
        _lastMoveTime = DateTime.now();
      },
      onPanUpdate: (details) {
        if (!widget.gameLogic.isGameRunning ||
            widget.gameLogic.isGameOver ||
            widget.gameLogic.isPaused) {
          return;
        }

        // Accumulate total movement
        _totalDx += details.delta.dx;
        _totalDy += details.delta.dy;

        final now = DateTime.now();
        final timeSinceLastMove = now.difference(_lastMoveTime);

        // Lock gesture direction once we have enough movement, preventing
        // accidental horizontal drift during a downward drag
        if (!_directionLocked &&
            (_totalDx.abs() >= _lockThreshold ||
                _totalDy.abs() >= _lockThreshold)) {
          _lockedHorizontal = _totalDx.abs() > _totalDy.abs();
          _directionLocked = true;
        }

        if (!_directionLocked) return;

        if (_lockedHorizontal) {
          // Horizontal movement - prevent accidental moves during slam
          if (_totalDx.abs() >= widget.moveThreshold &&
              !widget.gameLogic.isSlamming) {
            if (_totalDx > 0) {
              widget.gameLogic.movePieceRight();
            } else {
              widget.gameLogic.movePieceLeft();
            }
            _totalDx = 0.0;
            _lastMoveTime = now;
          }
          // Continuous horizontal movement
          else if (_totalDx.abs() >= widget.moveThreshold * 0.6 &&
              timeSinceLastMove >= _moveDelay &&
              details.delta.dx.abs() > 2.5 &&
              !widget.gameLogic.isSlamming) {
            if (_totalDx > 0) {
              widget.gameLogic.movePieceRight();
            } else {
              widget.gameLogic.movePieceLeft();
            }
            _totalDx = 0.0;
            _lastMoveTime = now;
          }
        } else {
          // Vertical movement - only downward, prevent during grace period
          if (_totalDy >= widget.moveThreshold &&
              !widget.gameLogic.isNewPieceGracePeriod) {
            widget.gameLogic.movePieceDown();
            _totalDy = 0.0;
            _lastMoveTime = now;
          }
          // Continuous downward movement
          else if (_totalDy >= widget.moveThreshold * 0.7 &&
              timeSinceLastMove >= _moveDelay &&
              details.delta.dy > 3.0 &&
              !widget.gameLogic.isNewPieceGracePeriod) {
            widget.gameLogic.movePieceDown();
            _totalDy = 0.0;
            _lastMoveTime = now;
          }
        }
      },
      onPanEnd: (details) {
        if (!widget.gameLogic.isGameRunning ||
            widget.gameLogic.isGameOver ||
            widget.gameLogic.isPaused) {
          return;
        }

        // Handle fast downward swipe for instant drop - much higher threshold
        // Also prevent hard drop during grace period
        if (details.velocity.pixelsPerSecond.dy > widget.fastSwipeVelocity &&
            details.velocity.pixelsPerSecond.dy >
                details.velocity.pixelsPerSecond.dx.abs() * 2 &&
            !widget.gameLogic.isNewPieceGracePeriod) {
          widget.gameLogic.dropPiece();
        }
        // Handle fast horizontal swipes - higher threshold and more restrictive
        // Also prevent horizontal movement during slam
        else if (details.velocity.pixelsPerSecond.dx.abs() > 600.0 &&
            details.velocity.pixelsPerSecond.dx.abs() >
                details.velocity.pixelsPerSecond.dy.abs() * 2 &&
            !widget.gameLogic.isSlamming) {
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
        _directionLocked = false;
        _lockedHorizontal = false;
      },
      child: widget.child,
    );
  }
}
