import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/theme/art_palette.dart';
import '../../application/unscramble_controller.dart';

/// Circular countdown ring with mm:ss. Turns amber and pulses under 30s,
/// red with a stronger pulse under 10s.
class TimerHud extends ConsumerWidget {
  const TimerHud({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(
      unscrambleControllerProvider.select((s) => s.secondsRemaining),
    );
    final progress = ref.watch(timerProgressProvider);
    final scheme = Theme.of(context).colorScheme;
    final game = GameColors.of(context);

    final phase = seconds <= 10 ? 2 : (seconds <= 30 ? 1 : 0);
    final color = switch (phase) {
      2 => scheme.error,
      1 => game.warning,
      _ => ArtPalette.purple,
    };
    final label =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

    Widget ring = SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: phase == 0 ? 0.3 : 0.45),
                  blurRadius: phase == 0 ? 14 : 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 900),
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
          Center(
            child: Text(
              label,
              style: GoogleFonts.fredoka(
                fontSize: size * 0.3,
                fontWeight: FontWeight.w700,
                color: phase == 0 ? ArtPalette.purpleDeep : color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );

    if (phase > 0) {
      // Keyed by phase so the pulse restarts with a new intensity at 10s.
      ring = ring
          .animate(key: ValueKey(phase), onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            end: phase == 2 ? 1.1 : 1.05,
            duration: phase == 2 ? 380.ms : 800.ms,
            curve: Curves.easeInOut,
          );
    }

    return Semantics(
      label: 'Time remaining ${seconds ~/ 60} minutes ${seconds % 60} seconds',
      excludeSemantics: true,
      child: ring,
    );
  }
}
