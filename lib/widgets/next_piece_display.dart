import 'package:flutter/material.dart';
import '../models/tetromino.dart';

class NextPieceDisplay extends StatelessWidget {
  final Tetromino piece;

  const NextPieceDisplay({super.key, required this.piece});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
      ),
      itemCount: 16,
      itemBuilder: (context, index) {
        int row = index ~/ 4;
        int col = index % 4;

        Color? cellColor;
        if (row < piece.shape.length && col < piece.shape[row].length) {
          cellColor = piece.shape[row][col] == 1 ? piece.color : null;
        }

        return Container(
          decoration: BoxDecoration(
            color: cellColor ?? Colors.transparent,
            border:
                cellColor != null
                    ? Border.all(color: Colors.grey[600]!, width: 0.5)
                    : null,
          ),
        );
      },
    );
  }
}
