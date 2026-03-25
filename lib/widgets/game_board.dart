import 'package:flutter/material.dart';
import '../constants/game_constants.dart';
import '../game/game_logic.dart';
import '../settings/settings_provider.dart';

// Modern Flutter color alpha helper
Color _colorWithAlpha(Color color, double alpha) {
  return color.withValues(alpha: alpha);
}

class GameBoard extends StatefulWidget {
  final List<List<Color?>> board;
  final int previewRows;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;
  final GameLogic gameLogic;
  final AppStyle style;

  const GameBoard({
    super.key,
    required this.board,
    required this.previewRows,
    required this.gameLogic,
    required this.style,
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

  late AnimationController _trailController;
  late Animation<double> _trailOpacityAnimation;

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

    _trailController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _trailOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _trailController, curve: Curves.easeOut));

    widget.gameLogic.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    if (widget.gameLogic.isAnimatingClear) {
      _clearController.forward();
    } else {
      _clearController.reset();
    }

    if (widget.gameLogic.isAnimatingTrail) {
      _trailController.forward();
    } else {
      _trailController.reset();
    }
  }

  @override
  void dispose() {
    widget.gameLogic.removeListener(_onGameStateChanged);
    _clearController.dispose();
    _trailController.dispose();
    super.dispose();
  }

  Widget _buildCell({
    required Color? displayColor,
    required bool isGhostPiece,
    required Color emptyCellColor,
    required Color cellBorderColor,
    required Color ghostBorder,
    required double cellW,
    required double cellH,
  }) {
    final style = widget.style;

    switch (style) {
      case AppStyle.classic:
        return Container(
          decoration: BoxDecoration(
            color: isGhostPiece
                ? emptyCellColor
                : (displayColor ?? emptyCellColor),
            border: Border.all(
              color: isGhostPiece ? ghostBorder : cellBorderColor,
              width: isGhostPiece ? 2.0 : 0.5,
            ),
          ),
        );

      case AppStyle.modern:
        const margin = EdgeInsets.all(1.5);
        const radius = 4.0;
        if (isGhostPiece) {
          return Container(
            margin: margin,
            decoration: BoxDecoration(
              color: emptyCellColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: ghostBorder, width: 1.5),
            ),
          );
        }
        if (displayColor == null) {
          return Container(
            margin: margin,
            decoration: BoxDecoration(
              color: emptyCellColor,
              borderRadius: BorderRadius.circular(radius),
            ),
          );
        }
        return Container(
          margin: margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(displayColor, Colors.white, 0.35)!,
                displayColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _colorWithAlpha(displayColor, 0.45),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        );

      case AppStyle.bubbles:
        final marginAmt = cellW * 0.1;
        final innerSize = cellW - 2 * marginAmt;
        final radius = innerSize / 2;
        final margin = EdgeInsets.all(marginAmt);

        if (isGhostPiece) {
          return Container(
            margin: margin,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: ghostBorder, width: 2.0),
            ),
          );
        }
        if (displayColor == null) {
          return Container(
            margin: margin,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: _colorWithAlpha(cellBorderColor, 0.25),
                width: 0.5,
              ),
            ),
          );
        }
        return Container(
          margin: margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.4),
              radius: 0.9,
              colors: [
                Color.lerp(displayColor, Colors.white, 0.65)!,
                displayColor,
                Color.lerp(displayColor, Colors.black, 0.25)!,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: _colorWithAlpha(displayColor, 0.55),
                blurRadius: 5,
                spreadRadius: 0.5,
              ),
            ],
          ),
        );

      case AppStyle.neon:
        if (isGhostPiece) {
          return Container(
            margin: const EdgeInsets.all(1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: _colorWithAlpha(ghostBorder, 0.4),
                width: 1,
              ),
            ),
          );
        }
        if (displayColor == null) {
          return Container(color: emptyCellColor);
        }
        return Container(
          margin: const EdgeInsets.all(1.0),
          decoration: BoxDecoration(
            color: _colorWithAlpha(displayColor, 0.12),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: displayColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _colorWithAlpha(displayColor, 0.8),
                blurRadius: 6,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: _colorWithAlpha(displayColor, 0.35),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
        );

      case AppStyle.retro:
        if (isGhostPiece) {
          return Container(
            decoration: BoxDecoration(
              color: emptyCellColor,
              border: Border.all(color: ghostBorder, width: 2.0),
            ),
          );
        }
        if (displayColor == null) {
          return Container(color: emptyCellColor);
        }
        final highlight = Color.lerp(displayColor, Colors.white, 0.6)!;
        final shadow = Color.lerp(displayColor, Colors.black, 0.5)!;
        const bevel = 3.0;
        return Container(
          color: displayColor,
          child: Stack(
            children: [
              // Top highlight
              Positioned(
                top: 0,
                left: 0,
                right: bevel,
                child: Container(height: bevel, color: highlight),
              ),
              // Left highlight
              Positioned(
                top: 0,
                left: 0,
                bottom: bevel,
                child: Container(width: bevel, color: highlight),
              ),
              // Bottom shadow
              Positioned(
                bottom: 0,
                left: bevel,
                right: 0,
                child: Container(height: bevel, color: shadow),
              ),
              // Right shadow
              Positioned(
                top: bevel,
                right: 0,
                bottom: 0,
                child: Container(width: bevel, color: shadow),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final emptyCellColor = isDark ? Colors.grey[900]! : const Color(0xFFEEEEEE);
    final cellBorderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final ghostBorder = GameConstants.ghostBorderColor(brightness);

    final int cols = widget.board[0].length;
    final int visibleRows = widget.board.length - widget.previewRows;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cellW = constraints.maxWidth / cols;
        final double cellH = constraints.maxHeight / visibleRows;
        final double aspectRatio =
            (constraints.maxHeight > 0 && constraints.maxWidth > 0)
                ? cellW / cellH
                : 1.0;

        return AnimatedBuilder(
          animation: Listenable.merge([_clearController, _trailController]),
          builder: (context, child) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                widget.onRightTap?.call();
              },
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: (widget.board.length - widget.previewRows) *
                    widget.board[0].length,
                itemBuilder: (context, index) {
                  int row =
                      (index ~/ widget.board[0].length) + widget.previewRows;
                  int col = index % widget.board[0].length;

                  Color? cellColor = widget.board[row][col];
                  bool isGhostPiece =
                      cellColor == GameConstants.ghostPieceColor;
                  bool isClearingLine =
                      widget.gameLogic.isLineClearingAnimation(row);

                  Map<String, dynamic>? trailBlock =
                      widget.gameLogic.getTrailBlock(col, row);

                  final displayColor = (cellColor != null && !isGhostPiece)
                      ? GameConstants.adaptPieceColor(cellColor, brightness)
                      : null;

                  Widget cellWidget = _buildCell(
                    displayColor: displayColor,
                    isGhostPiece: isGhostPiece,
                    emptyCellColor: emptyCellColor,
                    cellBorderColor: cellBorderColor,
                    ghostBorder: ghostBorder,
                    cellW: cellW,
                    cellH: cellH,
                  );

                  // ZOOP effect for clearing lines
                  if (isClearingLine && cellColor != null) {
                    double scale = _scaleAnimation.value;
                    double opacity = _opacityAnimation.value;
                    double glow = _glowAnimation.value;

                    Color glowColor =
                        Color.lerp(cellColor, Colors.white, glow * 0.7)!;

                    final borderRadius = widget.style == AppStyle.bubbles
                        ? BorderRadius.circular(cellW * 0.4)
                        : (widget.style == AppStyle.modern ||
                                widget.style == AppStyle.neon)
                            ? BorderRadius.circular(4)
                            : BorderRadius.zero;

                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: borderRadius,
                            boxShadow: glow > 0
                                ? [
                                    BoxShadow(
                                      color: _colorWithAlpha(
                                        glowColor,
                                        glow * 0.6,
                                      ),
                                      blurRadius: 8.0 * glow,
                                      spreadRadius: 3.0 * glow,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: glowColor,
                              borderRadius: borderRadius,
                              border: Border.all(
                                color:
                                    _colorWithAlpha(Colors.white, glow * 0.8),
                                width: 0.5 + (glow * 1.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // Trail effect for hard drop
                  if (trailBlock != null && cellColor == null) {
                    Color trailColor = trailBlock['color'] as Color;
                    double intensity = trailBlock['intensity'] as double;
                    double animationProgress =
                        1.0 - _trailOpacityAnimation.value;
                    double finalOpacity = intensity * animationProgress * 0.4;

                    final borderRadius = widget.style == AppStyle.bubbles
                        ? BorderRadius.circular(cellW * 0.4)
                        : (widget.style == AppStyle.modern ||
                                widget.style == AppStyle.neon)
                            ? BorderRadius.circular(4)
                            : BorderRadius.zero;

                    return Container(
                      decoration: BoxDecoration(
                        color: _colorWithAlpha(trailColor, finalOpacity * 0.3),
                        borderRadius: borderRadius,
                        border: Border.all(
                          color:
                              _colorWithAlpha(trailColor, finalOpacity * 0.5),
                          width: 0.5,
                        ),
                        boxShadow: finalOpacity > 0.1
                            ? [
                                BoxShadow(
                                  color: _colorWithAlpha(
                                    trailColor,
                                    finalOpacity * 0.2,
                                  ),
                                  blurRadius: 2.0 * finalOpacity,
                                  spreadRadius: 0.5 * finalOpacity,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }

                  return cellWidget;
                },
              ),
            );
          },
        );
      },
    );
  }
}
