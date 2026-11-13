import 'package:flutter/material.dart';

/// Draws a dark tile edged with a thin neon tube and a restrained halo.
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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide <= 0) return;
    final unit = size.shortestSide;
    final frame = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(unit * 0.065),
      Radius.circular(unit * 0.1),
    );
    final tubeWidth = (unit * 0.055).clamp(0.8, 1.8).toDouble();
    if (isGhost) {
      canvas.drawRRect(
        frame,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = tubeWidth,
      );
      return;
    }

    canvas.drawRRect(frame, Paint()..color = const Color(0xFF050A14));
    canvas.drawRRect(
      frame,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tubeWidth * 3,
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = tubeWidth,
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = Color.lerp(color, Colors.white, 0.65)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = tubeWidth * 0.4,
    );
  }

  @override
  bool shouldRepaint(_NeonBlockPainter oldDelegate) =>
      color != oldDelegate.color || isGhost != oldDelegate.isGhost;
}
