import 'package:flutter/material.dart';
import '../models/tetromino.dart';

class HoldPieceDisplay extends StatelessWidget {
  final Tetromino? piece;

  const HoldPieceDisplay({super.key, this.piece});

  @override
  Widget build(BuildContext context) {
    if (piece == null) {
      return Container(decoration: BoxDecoration(color: Colors.transparent));
    }

    // Calculate the bounds of the piece to center it
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

    // Calculate offset to center the piece in a 4x4 grid
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

        // Adjust for centering offset
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

        return Container(
          decoration: BoxDecoration(
            color: cellColor ?? Colors.transparent,
            border: cellColor != null
                ? Border.all(color: Colors.grey[600]!, width: 0.5)
                : null,
          ),
        );
      },
    );
  }
}
