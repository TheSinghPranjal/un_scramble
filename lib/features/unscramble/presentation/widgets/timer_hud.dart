import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../application/unscramble_controller.dart';

/// Circular countdown ring with mm:ss. Turns amber and pulses under 30s,
/// red with a stronger pulse under 10s.
class TimerHud extends ConsumerWidget {
  const TimerHud({super.key, this.size = 72});

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
      _ => scheme.primary,
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
              color: scheme.surfaceContainerLowest,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: phase == 0 ? 8 : 16,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 900),
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
          Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
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
