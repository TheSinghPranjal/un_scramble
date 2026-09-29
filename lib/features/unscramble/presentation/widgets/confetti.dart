import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight one-shot confetti burst (no package). Callers should skip it
/// when `MediaQuery.disableAnimationsOf(context)` is true.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.particleCount = 90});

  final int particleCount;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  late final List<_Particle> _particles = _generate();

  List<_Particle> _generate() {
    final random = math.Random();
    return List.generate(widget.particleCount, (_) {
      // Mostly upward, fanned out ±70°.
      final angle = -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 0.8;
      final speed = 0.7 + random.nextDouble() * 0.9;
      return _Particle(
        velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
        spin: (random.nextDouble() - 0.5) * 14,
        colorIndex: random.nextInt(6),
        size: 6 + random.nextDouble() * 6,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      const Color(0xFFFFC53D),
      const Color(0xFF3DD68C),
      const Color(0xFFFF6B8B),
    ];
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_controller, _particles, palette),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.velocity,
    required this.spin,
    required this.colorIndex,
    required this.size,
  });

  final Offset velocity;
  final double spin;
  final int colorIndex;
  final double size;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.animation, this.particles, this.palette)
    : super(repaint: animation);

  final Animation<double> animation;
  final List<_Particle> particles;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t >= 1) return;
    final origin = Offset(size.width / 2, size.height * 0.42);
    final scale = size.shortestSide;
    const gravity = 1.6;
    final paint = Paint();
    for (final p in particles) {
      final pos =
          origin +
          Offset(
            p.velocity.dx * t * scale,
            (p.velocity.dy * t + 0.5 * gravity * t * t) * scale,
          );
      paint.color = palette[p.colorIndex].withValues(alpha: 1 - t * t);
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(p.spin * t)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => false;
}
