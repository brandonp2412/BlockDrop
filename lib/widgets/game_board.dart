import 'package:flutter/material.dart';

class GameBoard extends StatelessWidget {
  final List<List<Color?>> board;
  final int previewRows;

  const GameBoard({super.key, required this.board, required this.previewRows});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: board[0].length,
      ),
      itemCount: (board.length - previewRows) * board[0].length,
      itemBuilder: (context, index) {
        int row = (index ~/ board[0].length) + previewRows;
        int col = index % board[0].length;

        Color? cellColor = board[row][col];

        return Container(
          decoration: BoxDecoration(
            color: cellColor ?? Colors.grey[900],
            border: Border.all(color: Colors.grey[800]!, width: 0.5),
          ),
        );
      },
    );
  }
}
