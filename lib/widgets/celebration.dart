import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Full-screen celebration with confetti, for rank-ups and streak milestones.
Future<void> showCelebration(
  BuildContext context, {
  required String title,
  required String badge,
  required String subtitle,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0xE60E1325),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, a1, a2) => CelebrationOverlay(
      title: title,
      badge: badge,
      subtitle: subtitle,
    ),
  );
}

class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.title,
    required this.badge,
    required this.subtitle,
  });

  final String title;
  final String badge;
  final String subtitle;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _Particle {
  const _Particle(this.angle, this.speed, this.size, this.spin, this.color);

  final double angle;
  final double speed;
  final double size;
  final double spin;
  final Color color;
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  static const List<Color> _palette = [
    AppColors.lime,
    AppColors.coral,
    AppColors.amber,
    Color(0xFF5BD6FF),
    Color(0xFFFF4FD8),
    AppColors.text,
  ];

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final List<_Particle> _particles = () {
    final r = Random(7);
    return List<_Particle>.generate(70, (i) {
      return _Particle(
        -pi * (0.12 + 0.76 * r.nextDouble()),
        280 + 520 * r.nextDouble(),
        6 + 7 * r.nextDouble(),
        (r.nextDouble() - 0.5) * 12,
        _palette[r.nextInt(_palette.length)],
      );
    });
  }();

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // People who turned animations off in Android get a still screen.
    final reduce = MediaQuery.of(context).disableAnimations;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          if (!reduce)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(
                    painter: _ConfettiPainter(_particles, _c.value),
                  ),
                ),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.lime,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, child) {
                      final x = _c.value / 0.5;
                      final t =
                          reduce ? 1.0 : Curves.elasticOut.transform(x > 1 ? 1.0 : x);
                      return Transform.scale(scale: t, child: child);
                    },
                    child: Container(
                      width: 160,
                      height: 160,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.amber, width: 6),
                      ),
                      child: FittedBox(
                        child: Text(
                          widget.badge,
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CONTINUE'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.progress);

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = progress * 2.4;
    final origin = Offset(size.width / 2, size.height * 0.42);
    final alpha = progress < 0.7 ? 1.0 : 1 - (progress - 0.7) / 0.3;
    if (alpha <= 0) return;
    for (final p in particles) {
      final x = origin.dx + cos(p.angle) * p.speed * seconds;
      final y = origin.dy +
          sin(p.angle) * p.speed * seconds +
          0.5 * 900 * seconds * seconds;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * seconds);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        Paint()..color = p.color.withOpacity(alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
