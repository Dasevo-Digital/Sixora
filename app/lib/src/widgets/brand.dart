import 'package:flutter/material.dart';

/// The Sixora mark: a shield with six dots, one per code digit.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _BrandPainter()),
  );
}

class _BrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(s * 0.24),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
        ).createShader(Offset.zero & size),
    );
    final shield = Path()
      ..moveTo(s * 0.5, s * 0.17)
      ..lineTo(s * 0.77, s * 0.27)
      ..lineTo(s * 0.77, s * 0.5)
      ..cubicTo(s * 0.77, s * 0.68, s * 0.64, s * 0.79, s * 0.5, s * 0.85)
      ..cubicTo(s * 0.36, s * 0.79, s * 0.23, s * 0.68, s * 0.23, s * 0.5)
      ..lineTo(s * 0.23, s * 0.27)
      ..close();
    canvas.drawPath(
      shield,
      Paint()..color = Colors.white.withValues(alpha: 0.96),
    );
    final dot = Paint()..color = const Color(0xFF4338CA);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        canvas.drawCircle(
          Offset(s * (0.375 + col * 0.125), s * (0.43 + row * 0.15)),
          s * 0.042,
          dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
