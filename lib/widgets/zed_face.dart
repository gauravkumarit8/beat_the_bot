import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/zed_voice.dart';

/// Zed's face, drawn in code so it needs no image files.
class ZedFace extends StatelessWidget {
  const ZedFace({
    super.key,
    required this.mood,
    this.size = 48,
    this.backdrop = false,
  });

  final ZedMood mood;
  final double size;

  /// Draws a round backdrop behind the face (used on the Home screen).
  final bool backdrop;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Zed looks ${mood.name}',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _ZedPainter(mood, backdrop)),
      ),
    );
  }
}

class _ZedPainter extends CustomPainter {
  _ZedPainter(this.mood, this.backdrop);

  final ZedMood mood;
  final bool backdrop;

  static const Color _headColor = Color(0xFF232C55);
  static const Color _shine = Color(0xFFFFD3CD);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 120;
    Paint fill(Color c) => Paint()..color = c;
    Paint line(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * k
      ..strokeCap = StrokeCap.round;

    if (backdrop) {
      canvas.drawCircle(Offset(60 * k, 60 * k), 58 * k, fill(AppColors.line));
    }

    // Antenna
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(57 * k, 16 * k, 6 * k, 22 * k), Radius.circular(2 * k)),
      fill(AppColors.muted),
    );
    canvas.drawCircle(Offset(60 * k, 15 * k), 6 * k, fill(AppColors.coral));

    // Head
    final head = RRect.fromRectAndRadius(
      Rect.fromLTWH(22 * k, 36 * k, 76 * k, 62 * k),
      Radius.circular(18 * k),
    );
    canvas.drawRRect(head, fill(_headColor));
    canvas.drawRRect(head, line(AppColors.lime, 4));

    final left = Offset(44 * k, 63 * k);
    final right = Offset(76 * k, 63 * k);

    void eye(Offset c, double r) {
      canvas.drawCircle(c, r * k, fill(AppColors.coral));
      canvas.drawCircle(
          c.translate(-r * 0.35 * k, -r * 0.35 * k), r * 0.3 * k, fill(_shine));
    }

    void brow(double x1, double y1, double x2, double y2) {
      canvas.drawLine(
          Offset(x1 * k, y1 * k), Offset(x2 * k, y2 * k), line(AppColors.coral, 4));
    }

    switch (mood) {
      case ZedMood.neutral:
        eye(left, 8);
        eye(right, 8);
        canvas.drawLine(Offset(47 * k, 83 * k), Offset(73 * k, 83 * k),
            line(AppColors.lime, 4));
      case ZedMood.smug:
        eye(left, 8);
        eye(right, 8);
        // Heavy eyelids
        for (final c in [left, right]) {
          canvas.drawRect(
              Rect.fromLTWH(c.dx - 10 * k, c.dy - 10 * k, 20 * k, 10 * k),
              fill(_headColor));
          canvas.drawLine(Offset(c.dx - 9 * k, c.dy), Offset(c.dx + 9 * k, c.dy),
              line(AppColors.lime, 3));
        }
        final smirk = Path()
          ..moveTo(46 * k, 84 * k)
          ..quadraticBezierTo(62 * k, 88 * k, 75 * k, 76 * k);
        canvas.drawPath(smirk, line(AppColors.lime, 4));
      case ZedMood.annoyed:
        eye(left, 7);
        eye(right, 7);
        brow(35, 49, 52, 57);
        brow(85, 49, 68, 57);
        canvas.drawLine(Offset(50 * k, 84 * k), Offset(70 * k, 84 * k),
            line(AppColors.lime, 4));
      case ZedMood.shocked:
        eye(left, 11);
        eye(right, 11);
        canvas.drawCircle(Offset(60 * k, 85 * k), 5 * k, line(AppColors.lime, 3));
      case ZedMood.sad:
        eye(left, 7);
        eye(right, 7);
        brow(35, 56, 52, 50);
        brow(85, 56, 68, 50);
        final frown = Path()
          ..moveTo(48 * k, 88 * k)
          ..quadraticBezierTo(60 * k, 78 * k, 72 * k, 88 * k);
        canvas.drawPath(frown, line(AppColors.lime, 4));
    }
  }

  @override
  bool shouldRepaint(_ZedPainter old) =>
      old.mood != mood || old.backdrop != backdrop;
}
