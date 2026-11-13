import 'package:flutter/material.dart';

/// Draws a neon tile with a clipped frame and a recessed, illuminated core.
class NeonBlock extends StatelessWidget {
  /// The piece color, or the landing indicator color for a ghost tile.
  final Color color;

  /// Shows only a subdued frame for the projected landing position.
  final bool isGhost;

  const NeonBlock({super.key, required this.color, this.isGhost = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: CustomPaint(painter: _NeonBlockPainter(color, isGhost)),
    );
  }
}

class _NeonBlockPainter extends CustomPainter {
  final Color color;
  final bool isGhost;

  const _NeonBlockPainter(this.color, this.isGhost);

  Path _frame(Rect rect) {
    final cut = rect.shortestSide * 0.18;
    return Path()
      ..moveTo(rect.left + cut, rect.top)
      ..lineTo(rect.right - cut, rect.top)
      ..lineTo(rect.right, rect.top + cut)
      ..lineTo(rect.right, rect.bottom - cut)
      ..lineTo(rect.right - cut, rect.bottom)
      ..lineTo(rect.left + cut, rect.bottom)
      ..lineTo(rect.left, rect.bottom - cut)
      ..lineTo(rect.left, rect.top + cut)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide <= 0) return;
    final bounds = Offset.zero & size;
    final unit = size.shortestSide;
    final frame = _frame(bounds.deflate(unit * 0.045));
    if (isGhost) {
      canvas.drawPath(
        frame,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.045,
      );
      return;
    }

    canvas.drawPath(frame, Paint()..color = const Color(0xFF050A14));
    canvas.drawPath(
      frame,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.065,
    );

    final coreBounds = bounds.deflate(unit * 0.19);
    canvas.drawPath(
      _frame(coreBounds),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.2)!,
            Color.lerp(color, const Color(0xFF050A14), 0.55)!,
          ],
        ).createShader(coreBounds),
    );

    final accent = Paint()
      ..color = Color.lerp(color, Colors.white, 0.75)!
      ..strokeWidth = unit * 0.055
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(unit * 0.23, unit * 0.07),
      Offset(size.width - unit * 0.23, unit * 0.07),
      accent,
    );
    canvas.drawLine(
      Offset(size.width - unit * 0.07, size.height - unit * 0.34),
      Offset(size.width - unit * 0.07, size.height - unit * 0.23),
      accent,
    );
  }

  @override
  bool shouldRepaint(_NeonBlockPainter oldDelegate) =>
      color != oldDelegate.color || isGhost != oldDelegate.isGhost;
}
