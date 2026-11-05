import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/theme.dart';

/// True when animations should be skipped: in tests, or when the player has
/// turned animations off in Android's accessibility settings.
bool fxReduced(BuildContext context) =>
    !Fx.animations || MediaQuery.of(context).disableAnimations;

/// Dark gradient, faint grid and slowly drifting colour glows.
class FutureBackdrop extends StatelessWidget {
  const FutureBackdrop({super.key, required this.t});

  final Animation<double> t;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: t,
        builder: (context, _) =>
            CustomPaint(painter: _BackdropPainter(t.value)),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1030), Color(0xFF0E1325), Color(0xFF0A0E1F)],
        ).createShader(rect),
    );

    void orb(Offset c, double r, Color color) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    final a = t * 2 * pi;
    orb(Offset(size.width * (0.88 + 0.04 * sin(a)), size.height * 0.08),
        size.width * 0.75, const Color(0x38B8F34A));
    orb(Offset(size.width * 0.02, size.height * (0.40 + 0.03 * cos(a))),
        size.width * 0.65, const Color(0x305BD6FF));
    orb(Offset(size.width * 0.95, size.height * (0.78 + 0.03 * sin(a + 1))),
        size.width * 0.7, const Color(0x28FF4FD8));

    final grid = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1;
    const step = 36.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = (t * step) % step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.t != t;
}

/// A glowing, slowly turning ring around [child] (Zed's face).
class ZedHalo extends StatelessWidget {
  const ZedHalo({
    super.key,
    required this.t,
    required this.size,
    required this.child,
  });

  final Animation<double> t;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: t,
                builder: (context, _) =>
                    CustomPaint(painter: _HaloPainter(t.value)),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: c, radius: r);
    final turn = GradientRotation(t * 2 * pi);
    final sweep = SweepGradient(
      colors: const [
        AppColors.lime,
        Fx.cyan,
        Fx.magenta,
        AppColors.lime,
      ],
      transform: turn,
    ).createShader(rect);
    // Soft glow first, then the crisp ring on top.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..shader = sweep,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = sweep,
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.t != t;
}

/// A progress bar made of small glowing segments, like a game HUD.
class SegmentBar extends StatelessWidget {
  const SegmentBar({super.key, required this.progress, this.segments = 24});

  final double progress;
  final int segments;

  @override
  Widget build(BuildContext context) {
    var filled = (progress.clamp(0.0, 1.0) * segments).floor();
    if (progress > 0 && filled == 0) filled = 1;
    return Row(
      children: [
        for (var i = 0; i < segments; i++)
          Expanded(
            child: Container(
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i < filled
                    ? Color.lerp(AppColors.lime, Fx.cyan, i / segments)
                    : AppColors.line,
                boxShadow: i == filled - 1
                    ? const [BoxShadow(color: Color(0x80B8F34A), blurRadius: 8)]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Fades and slides [child] up when it first appears. Later [index]s take a
/// little longer, so the screen builds itself in a cascade.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = fxReduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduce ? 1.0 : 0.0, end: 1.0),
      duration: reduce ? Duration.zero : Duration(milliseconds: 420 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

/// A calm, still version of the Home backdrop, for every other screen.
/// It is painted once, so it costs nothing while a game is being played.
class NeonScaffold extends StatelessWidget {
  const NeonScaffold({super.key, required this.body, this.bottomNavigationBar});

  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          const Positioned.fill(
            child: FutureBackdrop(t: AlwaysStoppedAnimation<double>(0)),
          ),
          Positioned.fill(child: body),
        ],
      ),
    );
  }
}

const BoxDecoration _glassDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C2554), Color(0xFF121838)],
  ),
);

/// A glass-style card: dark gradient fill and a faint cyan edge.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: _glassDecoration.gradient,
        border: Border.all(color: Fx.cyan.withAlpha(70)),
      ),
      child: child,
    );
  }
}

/// Like [GlassCard], for lists of tappable rows. The Material sits inside the
/// decoration, so taps still show their ripple.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.radius = 20});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: _glassDecoration.gradient,
        border: Border.all(color: Fx.cyan.withAlpha(70)),
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }
}
