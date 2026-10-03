import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/tetromino.dart';
import '../constants/game_constants.dart';
import '../settings/settings_provider.dart';
import 'game_decorations.dart';

/// Displays the held tetromino and reflects whether hold can be used.
class HoldPieceDisplay extends StatelessWidget {
  final Tetromino? piece;
  final AppStyle style;
  final bool isAvailable;
  final double cellWidth;
  final double cellHeight;

  const HoldPieceDisplay({
    super.key,
    this.piece,
    required this.style,
    required this.cellWidth,
    required this.cellHeight,
    this.isAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final boxDecoration = pieceBoxDecoration(style, colorScheme);
    const previewPadding = 6.0;
    final boxWidth =
        cellWidth * 4 + previewPadding * 2 + boxDecoration.padding.horizontal;
    final boxHeight =
        cellHeight * 4 + previewPadding * 2 + boxDecoration.padding.vertical;

    if (piece == null) {
      return Center(
        child: Container(
          key: const ValueKey('hold-piece-border'),
          width: boxWidth,
          height: boxHeight,
          decoration: boxDecoration,
        ),
      );
    }

    final brightness = Theme.of(context).brightness;

    int minRow = piece!.shape.length;
    int maxRow = -1;
    int minCol = piece!.shape[0].length;
    int maxCol = -1;

    for (int row = 0; row < piece!.shape.length; row++) {
      for (int col = 0; col < piece!.shape[row].length; col++) {
        if (piece!.shape[row][col] == 1) {
          if (row < minRow) minRow = row;
          if (row > maxRow) maxRow = row;
          if (col < minCol) minCol = col;
          if (col > maxCol) maxCol = col;
        }
      }
    }

    if (maxRow < minRow || maxCol < minCol) {
      return SizedBox(width: boxWidth, height: boxHeight);
    }

    final pieceWidth = maxCol - minCol + 1;
    final pieceHeight = maxRow - minRow + 1;

    final pieceGrid = SizedBox(
      width: cellWidth * pieceWidth,
      height: cellHeight * pieceHeight,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: pieceWidth,
          childAspectRatio: cellWidth / cellHeight,
        ),
        itemCount: pieceWidth * pieceHeight,
        itemBuilder: (context, index) {
          final row = index ~/ pieceWidth;
          final col = index % pieceWidth;
          final pieceRow = minRow + row;
          final pieceCol = minCol + col;
          final cellColor =
              piece!.shape[pieceRow][pieceCol] == 1 ? piece!.color : null;
          final displayColor = cellColor != null
              ? GameConstants.adaptPieceColor(cellColor, brightness)
              : null;

          return _buildCell(displayColor);
        },
      ),
    );

    final renderedPiece = isAvailable
        ? pieceGrid
        : Opacity(
            opacity: 0.45,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: pieceGrid,
            ),
          );

    return Semantics(
      label: context.l10n.text(
        isAvailable ? 'Held piece available' : 'Held piece unavailable',
      ),
      child: Center(
        child: Container(
          key: const ValueKey('hold-piece-border'),
          width: boxWidth,
          height: boxHeight,
          padding: const EdgeInsets.all(previewPadding),
          decoration: boxDecoration,
          clipBehavior: Clip.antiAlias,
          child: Center(child: renderedPiece),
        ),
      ),
    );
  }

  Widget _buildCell(Color? displayColor) {
    switch (style) {
      case AppStyle.classic:
        if (displayColor == null) return const SizedBox.shrink();
        return DecoratedBox(decoration: classicPieceDecoration(displayColor));

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
                color: displayColor.withValues(alpha: 0.45),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        );

      case AppStyle.bubbles:
        if (displayColor == null) return const SizedBox.shrink();
        final marginAmount = cellWidth * 0.1;
        final innerSize = cellWidth - 2 * marginAmount;
        return Container(
          margin: EdgeInsets.all(marginAmount),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(innerSize / 2),
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
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: displayColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: displayColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: displayColor.withValues(alpha: 0.25),
                blurRadius: 3,
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
