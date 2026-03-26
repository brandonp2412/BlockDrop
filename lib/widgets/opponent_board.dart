import 'package:flutter/material.dart';

/// A compact, read-only rendering of an opponent's Tetris board.
///
/// [cells] is a flat list of 200 palette indices (20 rows × 10 cols, row-major).
/// Index 0 = empty, 1–7 = the seven standard piece colours, 8 = garbage.
class OpponentBoard extends StatelessWidget {
  final List<int> cells;
  final double width;
  final double height;
  final bool isGameOver;

  const OpponentBoard({
    super.key,
    required this.cells,
    required this.width,
    required this.height,
    this.isGameOver = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: _OpponentBoardPainter(cells: cells),
          ),
          if (isGameOver)
            Container(
              width: width,
              height: height,
              color: Colors.black54,
              alignment: Alignment.center,
              child: const Text(
                'GAME\nOVER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpponentBoardPainter extends CustomPainter {
  final List<int> cells;

  // Palette matches the standard Tetris piece colours.
  // Index 0 is transparent (empty cell).
  static const List<Color> _palette = [
    Color(0x00000000), // 0 – empty
    Color(0xFF00BCD4), // 1 – I  cyan
    Color(0xFFFFEB3B), // 2 – O  yellow
    Color(0xFF9C27B0), // 3 – T  purple
    Color(0xFF4CAF50), // 4 – S  green
    Color(0xFFF44336), // 5 – Z  red
    Color(0xFF2196F3), // 6 – J  blue
    Color(0xFFFF9800), // 7 – L  orange
    Color(0xFF607080), // 8 – garbage grey-blue
  ];

  const _OpponentBoardPainter({required this.cells});

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / 10;
    final cellH = size.height / 20;
    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black26
      ..strokeWidth = 0.5;

    for (int i = 0; i < cells.length && i < 200; i++) {
      final row = i ~/ 10;
      final col = i % 10;
      final idx = cells[i].clamp(0, _palette.length - 1);
      if (idx == 0) continue;

      final rect = Rect.fromLTWH(
        col * cellW + 0.5,
        row * cellH + 0.5,
        cellW - 1.0,
        cellH - 1.0,
      );
      paint.color = _palette[idx];
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_OpponentBoardPainter old) => old.cells != cells;
}
