import 'package:flutter/material.dart';

class GameBoard extends StatelessWidget {
  final List<List<Color?>> board;
  final int previewRows;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;

  const GameBoard({
    super.key,
    required this.board,
    required this.previewRows,
    this.onLeftTap,
    this.onRightTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (TapDownDetails details) {
        if (onLeftTap == null && onRightTap == null) return;

        // Get the render box to determine the tap position
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Size size = renderBox.size;
        final Offset localPosition = details.localPosition;

        // Determine if tap was on left or right side
        if (localPosition.dx < size.width / 2) {
          // Left side tap
          onLeftTap?.call();
        } else {
          // Right side tap
          onRightTap?.call();
        }
      },
      child: GridView.builder(
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
      ),
    );
  }
}
