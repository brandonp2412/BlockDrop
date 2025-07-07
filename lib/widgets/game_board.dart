import 'package:flutter/material.dart';
import '../constants/game_constants.dart';
import '../game/game_logic.dart';

class GameBoard extends StatefulWidget {
  final List<List<Color?>> board;
  final int previewRows;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;
  final GameLogic gameLogic;

  const GameBoard({
    super.key,
    required this.board,
    required this.previewRows,
    required this.gameLogic,
    this.onLeftTap,
    this.onRightTap,
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  late AnimationController _clearController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _clearController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _clearController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _clearController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _clearController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Listen to game logic changes to trigger animations
    widget.gameLogic.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    if (widget.gameLogic.isAnimatingClear) {
      _clearController.forward();
    } else {
      _clearController.reset();
    }
  }

  @override
  void dispose() {
    widget.gameLogic.removeListener(_onGameStateChanged);
    _clearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clearController,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: (TapDownDetails details) {
            if (widget.onLeftTap == null && widget.onRightTap == null) return;

            // Get the render box to determine the tap position
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final Size size = renderBox.size;
            final Offset localPosition = details.localPosition;

            // Determine if tap was on left or right side
            if (localPosition.dx < size.width / 2) {
              // Left side tap
              widget.onLeftTap?.call();
            } else {
              // Right side tap
              widget.onRightTap?.call();
            }
          },
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.board[0].length,
            ),
            itemCount:
                (widget.board.length - widget.previewRows) *
                widget.board[0].length,
            itemBuilder: (context, index) {
              int row = (index ~/ widget.board[0].length) + widget.previewRows;
              int col = index % widget.board[0].length;

              Color? cellColor = widget.board[row][col];
              bool isGhostPiece = cellColor == GameConstants.ghostPieceColor;
              bool isClearingLine = widget.gameLogic.isLineClearingAnimation(
                row,
              );

              // Normal cell widget
              Widget cellWidget = Container(
                decoration: BoxDecoration(
                  color:
                      isGhostPiece
                          ? Colors.grey[900]
                          : (cellColor ?? Colors.grey[900]),
                  border: Border.all(
                    color:
                        isGhostPiece
                            ? GameConstants.ghostPieceColor
                            : Colors.grey[800]!,
                    width: isGhostPiece ? 2.0 : 0.5,
                  ),
                ),
              );

              // ZOOP effect for clearing lines - clean and satisfying
              if (isClearingLine && cellColor != null) {
                // Stagger animation based on column position for smooth wave
                double staggerDelay = col * 0.05;
                double adjustedProgress =
                    (_clearController.value + staggerDelay).clamp(0.0, 1.0);

                // Calculate individual animation values
                double scale = _scaleAnimation.value;
                double opacity = _opacityAnimation.value;
                double glow = _glowAnimation.value;

                // Create a clean, bright glow color based on original block color
                Color glowColor =
                    Color.lerp(cellColor, Colors.white, glow * 0.7)!;

                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow:
                            glow > 0
                                ? [
                                  BoxShadow(
                                    color: glowColor.withOpacity(glow * 0.6),
                                    blurRadius: 8.0 * glow,
                                    spreadRadius: 3.0 * glow,
                                  ),
                                ]
                                : null,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: glowColor,
                          border: Border.all(
                            color: Colors.white.withOpacity(glow * 0.8),
                            width: 0.5 + (glow * 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return cellWidget;
            },
          ),
        );
      },
    );
  }
}
