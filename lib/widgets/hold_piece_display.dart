import 'package:flutter/material.dart';
import '../models/tetromino.dart';
import '../constants/game_constants.dart';
import '../settings/settings_provider.dart';

class HoldPieceDisplay extends StatelessWidget {
  final Tetromino? piece;
  final AppStyle style;

  const HoldPieceDisplay({
    super.key,
    this.piece,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (piece == null) {
      return Container(
          decoration: const BoxDecoration(color: Colors.transparent));
    }
    final brightness = Theme.of(context).brightness;

    int minRow = piece!.shape.length;
    int maxRow = -1;
    int minCol = piece!.shape[0].length;
    int maxCol = -1;

    for (int row = 0; row < piece!.shape.length; row++) {
      for (int col = 0; col < piece!.shape[row].length; col++) {
        if (piece!.shape[row][col] == 1) {
          minRow = minRow < row ? minRow : row;
          maxRow = maxRow > row ? maxRow : row;
          minCol = minCol < col ? minCol : col;
          maxCol = maxCol > col ? maxCol : col;
        }
      }
    }

    int pieceWidth = maxCol - minCol + 1;
    int pieceHeight = maxRow - minRow + 1;

    int offsetX = (4 - pieceWidth) ~/ 2;
    int offsetY = (4 - pieceHeight) ~/ 2;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
      ),
      itemCount: 16,
      itemBuilder: (context, index) {
        int row = index ~/ 4;
        int col = index % 4;

        int pieceRow = row - offsetY + minRow;
        int pieceCol = col - offsetX + minCol;

        Color? cellColor;
        if (pieceRow >= 0 &&
            pieceRow < piece!.shape.length &&
            pieceCol >= 0 &&
            pieceCol < piece!.shape[pieceRow].length &&
            piece!.shape[pieceRow][pieceCol] == 1) {
          cellColor = piece!.color;
        }

        final displayColor = cellColor != null
            ? GameConstants.adaptPieceColor(cellColor, brightness)
            : null;

        return _buildCell(displayColor);
      },
    );
  }

  Widget _buildCell(Color? displayColor) {
    switch (style) {
      case AppStyle.classic:
        return Container(
          decoration: BoxDecoration(
            color: displayColor ?? Colors.transparent,
            border: displayColor != null
                ? Border.all(color: Colors.grey[600]!, width: 0.5)
                : null,
          ),
        );

      case AppStyle.modern:
        if (displayColor == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
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
                color: displayColor.withValues(alpha: 0.4),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        );

      case AppStyle.bubbles:
        if (displayColor == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
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
                color: displayColor.withValues(alpha: 0.55),
                blurRadius: 5,
                spreadRadius: 0.5,
              ),
            ],
          ),
        );

      case AppStyle.neon:
        if (displayColor == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: displayColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: displayColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: displayColor.withValues(alpha: 0.8),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );

      case AppStyle.retro:
        if (displayColor == null) return const SizedBox.shrink();
        final highlight = Color.lerp(displayColor, Colors.white, 0.6)!;
        final shadow = Color.lerp(displayColor, Colors.black, 0.5)!;
        const bevel = 3.0;
        return Container(
          color: displayColor,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: bevel,
                child: Container(height: bevel, color: highlight),
              ),
              Positioned(
                top: 0,
                left: 0,
                bottom: bevel,
                child: Container(width: bevel, color: highlight),
              ),
              Positioned(
                bottom: 0,
                left: bevel,
                right: 0,
                child: Container(height: bevel, color: shadow),
              ),
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
}
