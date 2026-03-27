import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../audio/audio_service.dart';
import '../constants/game_constants.dart';
import '../game/game_logic.dart';
import '../multiplayer/multiplayer_manager.dart';
import '../settings/settings_provider.dart';
import '../widgets/game_board.dart';
import '../widgets/game_decorations.dart';
import '../widgets/hold_piece_display.dart';
import '../widgets/next_piece_display.dart';
import '../widgets/opponent_board.dart';
import '../widgets/swipe_detector.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final MultiplayerManager manager;
  final SettingsProvider settings;

  const MultiplayerGameScreen({
    super.key,
    required this.manager,
    required this.settings,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen>
    with WidgetsBindingObserver {
  late GameLogic _gameLogic;
  late AudioService _audioService;

  // Countdown before game starts
  int _countdown = 3;
  bool _gameActive = false;
  Timer? _countdownTimer;

  // Snapshot sender
  Timer? _snapshotTimer;

  // Result overlay
  bool _showResult = false;
  bool _iWon = false;

  // Incoming garbage flash
  int _incomingGarbage = 0;
  Timer? _garbageFlashTimer;

  static const double _moveThreshold = 18.0;
  static const double _fastSwipeVelocity = 1000.0;

  final _fmt = NumberFormat.decimalPattern('en_US');

  @override
  void initState() {
    super.initState();

    _audioService = AudioService(
      musicEnabled: widget.settings.musicEnabled,
      sfxEnabled: widget.settings.sfxEnabled,
    );
    _audioService.init().then((_) {
      if (widget.settings.musicEnabled) _audioService.startMusic();
    });

    _gameLogic = GameLogic();
    _gameLogic.audioService = _audioService;
    _gameLogic.addListener(_onGameStateChanged);

    // Wire up multiplayer callbacks
    widget.manager.onGarbageReceived = _onGarbageReceived;
    widget.manager.onError = _onNetworkError;
    widget.manager.addListener(_onManagerChanged);

    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    _startCountdown();
  }

  void _startCountdown() {
    _countdown = 3;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _countdownTimer = null;
        _activateGame();
      }
    });
  }

  void _activateGame() {
    setState(() => _gameActive = true);
    _gameLogic.startGame();

    // Hook the line-clear callback NOW (after startGame resets state)
    _gameLogic.onLinesCleared = (count, tSpin) {
      final garbage = _garbageForLines(count, tSpin);
      if (garbage > 0) widget.manager.sendGarbage(garbage);
    };

    // Send board snapshots every 500 ms
    _snapshotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (!_gameLogic.isGameOver) {
        widget.manager.sendBoardSnapshot(
          _gameLogic.exportBoardSnapshot(),
          _gameLogic.score,
          _gameLogic.linesCleared,
        );
      }
    });
  }

  static int _garbageForLines(int lines, bool tSpin) {
    if (tSpin) return const [0, 2, 4, 6][lines <= 3 ? lines : 3];
    return const [0, 0, 1, 2, 4][lines <= 4 ? lines : 4];
  }

  void _onGarbageReceived(int lines) {
    if (!mounted || !_gameActive) return;
    _gameLogic.receiveGarbage(lines);
    // Flash the incoming indicator
    setState(() => _incomingGarbage = lines);
    _garbageFlashTimer?.cancel();
    _garbageFlashTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _incomingGarbage = 0);
    });
  }

  void _onNetworkError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
    // If the opponent disconnects during play, treat as opponent quit
    if (_gameActive && !_showResult) {
      setState(() {
        _showResult = true;
        _iWon = true;
      });
    }
  }

  void _onManagerChanged() {
    if (!mounted) return;
    // Opponent topped out
    if (widget.manager.opponentIsGameOver && _gameActive && !_showResult) {
      // If we're still alive we win; if we're also over it's simultaneous
      if (!_gameLogic.isGameOver) {
        setState(() {
          _showResult = true;
          _iWon = true;
        });
        _gameLogic.pauseGame();
      }
    }
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {});
    if (_gameLogic.isGameOver && _gameActive && !_showResult) {
      widget.manager.sendGameOver(_gameLogic.score);
      // Only show "you lose" if opponent hasn't lost yet
      if (!widget.manager.opponentIsGameOver) {
        setState(() {
          _showResult = true;
          _iWon = false;
        });
      } else {
        // Both topped out at the same time – higher score wins
        setState(() {
          _showResult = true;
          _iWon = _gameLogic.score >= widget.manager.opponentScore;
        });
      }
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (!_gameActive || _gameLogic.isGameOver || _gameLogic.isPaused) {
      return false;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _gameLogic.movePieceLeft();
        return true;
      case LogicalKeyboardKey.arrowRight:
        _gameLogic.movePieceRight();
        return true;
      case LogicalKeyboardKey.arrowDown:
        _gameLogic.movePieceDown();
        return true;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyZ:
        if (event is KeyDownEvent) _gameLogic.rotatePiece();
        return true;
      case LogicalKeyboardKey.keyX:
        if (event is KeyDownEvent) _gameLogic.rotatePieceRight();
        return true;
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.select:
        if (event is KeyDownEvent) _gameLogic.dropPiece();
        return true;
      case LogicalKeyboardKey.keyC:
      case LogicalKeyboardKey.mediaPlayPause:
        if (event is KeyDownEvent) _gameLogic.holdPiece();
        return true;
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_gameLogic.isGameRunning && !_gameLogic.isGameOver) {
        _gameLogic.pauseGame();
        _audioService.pauseMusic();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_gameLogic.isGameRunning && _gameLogic.isPaused) {
        _gameLogic.resumeGame();
        if (widget.settings.musicEnabled) _audioService.resumeMusic();
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _snapshotTimer?.cancel();
    _garbageFlashTimer?.cancel();
    _gameLogic.onLinesCleared = null;
    _gameLogic.removeListener(_onGameStateChanged);
    _gameLogic.dispose();
    widget.manager.removeListener(_onManagerChanged);
    widget.manager.onGarbageReceived = null;
    widget.manager.onError = null;
    _audioService.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_gameLogic.isGameRunning &&
            !_gameLogic.isGameOver &&
            !_gameLogic.isPaused &&
            _gameLogic.canHold) {
          _gameLogic.holdPiece();
        } else {
          if (!didPop) _confirmLeave();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              _buildGameLayout(),
              if (!_gameActive) _buildCountdownOverlay(),
              if (_showResult) _buildResultOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 500) {
          return _buildWideLayout(constraints);
        }
        return _buildNarrowLayout(constraints);
      },
    );
  }

  // ── Wide layout (desktop / tablet) ────────────────────────────────────────
  // Hold|Next sidebar  |  your board + score  |  opponent board + score

  Widget _buildWideLayout(BoxConstraints constraints) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final totalW = constraints.maxWidth - 16;

    const double kOverhead = 110.0;
    final screenH = mq.size.height - mq.padding.top - mq.padding.bottom;
    final availableH = (screenH - kOverhead).clamp(100.0, double.infinity);

    // Reserve space for hold/next sidebar
    const double sidebarW = 72.0;
    const double sidebarGap = 8.0;
    final boardsW = totalW - sidebarW - sidebarGap;

    final yourBoardWByWidth = boardsW * 0.59;
    final yourBoardWByHeight = availableH / 2;
    final yourBoardW = yourBoardWByWidth < yourBoardWByHeight
        ? yourBoardWByWidth
        : yourBoardWByHeight;
    final yourBoardH = yourBoardW * 2;

    final oppBoardW = yourBoardW * (0.40 / 0.57);
    final oppBoardH = oppBoardW * 2;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hold / Next sidebar ──────────────────────────────────────
            SizedBox(
              width: sidebarW,
              child: Column(
                children: [
                  _buildSidebarPieceBox(
                    label: 'HOLD',
                    size: sidebarW,
                    cs: cs,
                    onTap: () {
                      if (_gameActive &&
                          _gameLogic.isGameRunning &&
                          !_gameLogic.isGameOver &&
                          !_gameLogic.isPaused) {
                        _gameLogic.holdPiece();
                      }
                    },
                    child: HoldPieceDisplay(
                      piece: _gameLogic.heldPiece,
                      style: widget.settings.style,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarPieceBox(
                    label: 'NEXT',
                    size: sidebarW,
                    cs: cs,
                    child: _gameLogic.nextPiece != null
                        ? NextPieceDisplay(
                            piece: _gameLogic.nextPiece!,
                            style: widget.settings.style,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            SizedBox(width: sidebarGap),

            // ── Your board ───────────────────────────────────────────────
            SizedBox(
              width: yourBoardW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _YourScoreHeader(
                    gameLogic: _gameLogic,
                    formatter: _fmt,
                    colorScheme: cs,
                  ),
                  const SizedBox(height: 4),
                  SwipeDetector(
                    gameLogic: _gameLogic,
                    moveThreshold: _moveThreshold,
                    fastSwipeVelocity: _fastSwipeVelocity,
                    child: Container(
                      width: yourBoardW,
                      height: yourBoardH,
                      decoration: boardDecoration(widget.settings.style, cs),
                      child: GameBoard(
                        board: _gameLogic.getBoardWithCurrentPiece(),
                        previewRows: GameConstants.previewRows,
                        gameLogic: _gameLogic,
                        style: widget.settings.style,
                        onLeftTap: () {
                          if (_gameActive &&
                              _gameLogic.isGameRunning &&
                              !_gameLogic.isGameOver &&
                              !_gameLogic.isPaused) {
                            _gameLogic.rotatePieceLeft();
                          }
                        },
                        onRightTap: () {
                          if (_gameActive &&
                              _gameLogic.isGameRunning &&
                              !_gameLogic.isGameOver &&
                              !_gameLogic.isPaused) {
                            _gameLogic.rotatePieceRight();
                          }
                        },
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _incomingGarbage > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.error.withAlpha(200),
                        borderRadius: panelBorderRadius(widget.settings.style),
                      ),
                      child: Text(
                        '⚠ +$_incomingGarbage garbage',
                        style: TextStyle(
                          color: cs.onError,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: totalW * 0.03),

            // ── Opponent side ────────────────────────────────────────────
            SizedBox(
              width: oppBoardW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OpponentScoreHeader(
                    manager: widget.manager,
                    formatter: _fmt,
                    colorScheme: cs,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: cs.outline.withAlpha(120),
                        width: widget.settings.style == AppStyle.retro ? 2 : 1,
                      ),
                      borderRadius: panelBorderRadius(widget.settings.style),
                    ),
                    child: OpponentBoard(
                      cells: widget.manager.opponentBoard,
                      width: oppBoardW,
                      height: oppBoardH,
                      isGameOver: widget.manager.opponentIsGameOver,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarPieceBox({
    required String label,
    required double size,
    required ColorScheme cs,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: size,
            height: size,
            decoration: pieceBoxDecoration(widget.settings.style, cs),
            child: child,
          ),
        ],
      ),
    );
  }

  // ── Narrow layout (mobile portrait) ───────────────────────────────────────
  // Full-screen board with hold, next, opponent board, and score as overlays.

  Widget _buildNarrowLayout(BoxConstraints constraints) {
    final cs = Theme.of(context).colorScheme;
    final totalH = constraints.maxHeight;
    final totalW = constraints.maxWidth;

    // Board fills the screen at 1:2 ratio (10 cols × 20 rows)
    double boardW = totalW;
    double boardH = boardW * 2;
    if (boardH > totalH) {
      boardH = totalH;
      boardW = boardH / 2;
    }
    final boardLeft = (totalW - boardW) / 2;
    final boardTop = (totalH - boardH) / 2;
    // Positioned.right is measured from the Stack's right edge
    final boardRight = boardLeft; // symmetric centering

    // Opponent overlay: ~26% of screen width
    final oppW = totalW * 0.26;
    final oppH = oppW * 2;

    const double overlayBoxSize = 58.0;
    const double labelH = 16.0; // height of the HOLD/NEXT label text

    return SizedBox(
      width: totalW,
      height: totalH,
      child: Stack(
        children: [
          // ── Main board ────────────────────────────────────────────
          Positioned(
            left: boardLeft,
            top: boardTop,
            child: SwipeDetector(
              gameLogic: _gameLogic,
              moveThreshold: _moveThreshold,
              fastSwipeVelocity: _fastSwipeVelocity,
              child: Container(
                width: boardW,
                height: boardH,
                decoration: boardDecoration(widget.settings.style, cs),
                child: GameBoard(
                  board: _gameLogic.getBoardWithCurrentPiece(),
                  previewRows: GameConstants.previewRows,
                  gameLogic: _gameLogic,
                  style: widget.settings.style,
                  onLeftTap: () {
                    if (_gameActive &&
                        _gameLogic.isGameRunning &&
                        !_gameLogic.isGameOver &&
                        !_gameLogic.isPaused) {
                      _gameLogic.rotatePieceLeft();
                    }
                  },
                  onRightTap: () {
                    if (_gameActive &&
                        _gameLogic.isGameRunning &&
                        !_gameLogic.isGameOver &&
                        !_gameLogic.isPaused) {
                      _gameLogic.rotatePieceRight();
                    }
                  },
                ),
              ),
            ),
          ),

          // ── Hold overlay (top-left of board) ──────────────────────
          Positioned(
            left: boardLeft + 4,
            top: boardTop + 4,
            child: _buildOverlayPieceBox(
              label: 'HOLD',
              size: overlayBoxSize,
              onTap: () {
                if (_gameActive &&
                    _gameLogic.isGameRunning &&
                    !_gameLogic.isGameOver &&
                    !_gameLogic.isPaused) {
                  _gameLogic.holdPiece();
                }
              },
              child: HoldPieceDisplay(
                piece: _gameLogic.heldPiece,
                style: widget.settings.style,
              ),
            ),
          ),

          // ── Next overlay (below hold) ──────────────────────────────
          Positioned(
            left: boardLeft + 4,
            top: boardTop + 4 + labelH + overlayBoxSize + 6,
            child: _buildOverlayPieceBox(
              label: 'NEXT',
              size: overlayBoxSize,
              child: _gameLogic.nextPiece != null
                  ? NextPieceDisplay(
                      piece: _gameLogic.nextPiece!,
                      style: widget.settings.style,
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // ── Opponent overlay (top-right, semi-transparent) ─────────
          Positioned(
            right: boardRight + 4,
            top: boardTop + 4,
            child: Opacity(
              opacity: 0.80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withAlpha(200),
                      borderRadius: panelBorderRadius(widget.settings.style),
                    ),
                    child: Text(
                      (widget.manager.opponentName ?? 'OPP').toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: cs.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: cs.outline.withAlpha(100),
                        width: widget.settings.style == AppStyle.retro ? 2 : 1,
                      ),
                      borderRadius: panelBorderRadius(widget.settings.style),
                      color: cs.surface.withAlpha(66),
                    ),
                    child: OpponentBoard(
                      cells: widget.manager.opponentBoard,
                      width: oppW,
                      height: oppH,
                      isGameOver: widget.manager.opponentIsGameOver,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Your score (bottom-left of board) ─────────────────────
          Positioned(
            left: boardLeft + 4,
            bottom: boardTop + 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(200),
                borderRadius: panelBorderRadius(widget.settings.style),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmt.format(_gameLogic.score),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'Lv ${_gameLogic.level}  ·  ${_gameLogic.linesCleared} lines',
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Incoming garbage indicator (bottom-center of board) ────
          Positioned(
            left: boardLeft,
            right: boardRight,
            bottom: boardTop + 4,
            child: AnimatedOpacity(
              opacity: _incomingGarbage > 0 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.error.withAlpha(200),
                    borderRadius: panelBorderRadius(widget.settings.style),
                  ),
                  child: Text(
                    '⚠ +$_incomingGarbage garbage',
                    style: TextStyle(
                      color: cs.onError,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayPieceBox({
    required String label,
    required double size,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final style = widget.settings.style;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: cs.onSurface.withAlpha(178),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withAlpha(200),
              border: Border.all(
                color: cs.outline.withAlpha(80),
                width: style == AppStyle.retro ? 2 : 1,
              ),
              borderRadius: panelBorderRadius(style),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  // ── Countdown overlay ─────────────────────────────────────────────────────

  Widget _buildCountdownOverlay() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface.withAlpha(180),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.manager.opponentName != null
                ? 'vs ${widget.manager.opponentName}'
                : 'Get Ready',
            style: TextStyle(
              color: cs.onSurface.withAlpha(178),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _countdown > 0 ? '$_countdown' : 'GO!',
            style: TextStyle(
              color: _countdown > 0 ? cs.onSurface : cs.primary,
              fontSize: 72,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(blurRadius: 12, color: Colors.black)],
            ),
          ),
        ],
      ),
    );
  }

  // ── Result overlay ────────────────────────────────────────────────────────

  Widget _buildResultOverlay() {
    final cs = Theme.of(context).colorScheme;
    final style = widget.settings.style;
    return Container(
      color: cs.surface.withAlpha(220),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _iWon ? '🎉 You Win!' : 'Game Over',
              style: TextStyle(
                color: _iWon ? cs.tertiary : cs.error,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _ResultRow(
              label: 'Your score',
              value: _fmt.format(_gameLogic.score),
              highlight: _iWon,
              colorScheme: cs,
            ),
            const SizedBox(height: 6),
            _ResultRow(
              label: '${widget.manager.opponentName ?? "Opponent"}\'s score',
              value: _fmt.format(widget.manager.opponentScore),
              highlight: !_iWon,
              colorScheme: cs,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      shape: buttonBorderShape(style),
                    ),
                    child: const Text('Play Again'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      shape: buttonBorderShape(style),
                    ),
                    child: const Text('Leave'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Leave confirmation ────────────────────────────────────────────────────

  Future<void> _confirmLeave() async {
    final cs = Theme.of(context).colorScheme;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: styledDialogShape(widget.settings.style, cs),
        title: const Text('Leave Game?'),
        content: const Text('Your opponent will be disconnected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _YourScoreHeader extends StatelessWidget {
  final GameLogic gameLogic;
  final NumberFormat formatter;
  final ColorScheme colorScheme;

  const _YourScoreHeader({
    required this.gameLogic,
    required this.formatter,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOU',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: colorScheme.primary,
          ),
        ),
        Text(
          formatter.format(gameLogic.score),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          'Lv ${gameLogic.level}  ·  ${gameLogic.linesCleared} lines',
          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _OpponentScoreHeader extends StatelessWidget {
  final MultiplayerManager manager;
  final NumberFormat formatter;
  final ColorScheme colorScheme;

  const _OpponentScoreHeader({
    required this.manager,
    required this.formatter,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (manager.opponentName ?? 'OPPONENT').toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: colorScheme.secondary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          formatter.format(manager.opponentScore),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          '${manager.opponentLines} lines',
          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final ColorScheme colorScheme;

  const _ResultRow({
    required this.label,
    required this.value,
    required this.highlight,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color:
                highlight ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
