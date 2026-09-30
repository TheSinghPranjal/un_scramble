import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../shared/theme/art_palette.dart';

/// Glossy yellow star that bobs gently. Purely decorative.
class ArtStar extends StatelessWidget {
  const ArtStar({super.key, required this.size, this.turns = 0});

  final double size;

  /// Resting tilt, in full turns.
  final double turns;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child:
            Transform.rotate(
                  angle: turns * 2 * math.pi,
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [ArtPalette.goldLight, ArtPalette.gold],
                    ).createShader(rect),
                    child: Icon(
                      Icons.star_rounded,
                      size: size,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: const Color(
                            0xFFC77A00,
                          ).withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                  begin: -3,
                  end: 3,
                  duration: 1800.ms,
                  curve: Curves.easeInOut,
                ),
      ),
    );
  }
}

/// Three short yellow strokes fanning out from a corner, like a "pop".
/// [mirrored] flips them to point up-left instead of up-right.
class SparkRays extends StatelessWidget {
  const SparkRays({super.key, this.size = 36, this.mirrored = false});

  final double size;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Transform.flip(
          flipX: mirrored,
          child: CustomPaint(
            size: Size.square(size),
            painter: const _SparkRaysPainter(),
          ),
        ),
      ),
    );
  }
}

class _SparkRaysPainter extends CustomPainter {
  const _SparkRaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.13
      ..shader = const LinearGradient(
        colors: [ArtPalette.goldLight, ArtPalette.gold],
      ).createShader(Offset.zero & size);
    // Rays radiate from the bottom-left corner towards the top-right.
    final origin = Offset(0, size.height);
    for (final a in [-0.2, -0.75, -1.3]) {
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        origin + dir * size.width * 0.45,
        origin + dir * size.width * 0.95,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
