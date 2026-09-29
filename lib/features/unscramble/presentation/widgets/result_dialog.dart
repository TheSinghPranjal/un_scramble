import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/models.dart';
import 'confetti.dart';
import 'letter_tile_face.dart';

/// Win / out-of-lives / timeout dialog. Always reveals the target word.
Future<void> showResultDialog(
  BuildContext context, {
  required UnscrambleGameState state,
  required VoidCallback onNext,
  required VoidCallback onRetry,
  required VoidCallback onHome,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => PopScope(
      canPop: false,
      child: Stack(
        children: [
          if (state.status == GameStatus.won && !reduceMotion)
            const Positioned.fill(child: ConfettiBurst()),
          Center(
            child: _ResultCard(
              state: state,
              onNext: onNext,
              onRetry: onRetry,
              onHome: onHome,
            ),
          ),
        ],
      ),
    ),
    transitionBuilder: (context, animation, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.state,
    required this.onNext,
    required this.onRetry,
    required this.onHome,
  });

  final UnscrambleGameState state;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = GameColors.of(context);
    final won = state.status == GameStatus.won;

    final (
      IconData icon,
      Color iconColor,
      String title,
      String subtitle,
    ) = switch (state.status) {
      GameStatus.won => (
        Icons.emoji_events_rounded,
        colors.warning,
        'Brilliant!',
        'You unscrambled it.',
      ),
      GameStatus.lostTimeout => (
        Icons.timer_off_rounded,
        scheme.error,
        "Time's up!",
        'The word was:',
      ),
      _ => (
        Icons.heart_broken_rounded,
        scheme.error,
        'Out of lives',
        'The word was:',
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(icon, size: 56, color: iconColor).animate().scaleXY(
                  begin: 0.4,
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _RevealedWord(word: state.targetWord),
                const SizedBox(height: 20),
                if (won) ...[
                  Row(
                    children: [
                      _Stat(
                        icon: Icons.timer_rounded,
                        label: 'Time left',
                        value:
                            '${state.secondsRemaining ~/ 60}:'
                            '${(state.secondsRemaining % 60).toString().padLeft(2, '0')}',
                      ),
                      _Stat(
                        icon: Icons.favorite_rounded,
                        label: 'Lives left',
                        value: '${state.livesRemaining}/$kMaxLives',
                      ),
                      _Stat(
                        icon: Icons.star_rounded,
                        label: 'Points',
                        value: '+${state.lastRoundScore}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next word'),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Next word'),
                  ),
                  const SizedBox(height: 8),
                  // TODO(monetization): rewarded ad → restore 1 life and resume.
                  const OutlinedButton(
                    onPressed: null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Extra life (Ad)'),
                        Text('Coming soon', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                TextButton(onPressed: onHome, child: const Text('Home')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealedWord extends StatelessWidget {
  const _RevealedWord({required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        final size = math.min(
          40.0,
          (constraints.maxWidth - gap * (word.length - 1)) / word.length,
        );
        return Semantics(
          label: 'The word was $word',
          excludeSemantics: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < word.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                LetterTileFace(
                      char: word[i],
                      width: size,
                      height: size * 1.1,
                      tone: TileTone.locked,
                    )
                    .animate(delay: (80 * i).ms)
                    .fadeIn(duration: 200.ms)
                    .slideY(begin: 0.5, curve: Curves.easeOutBack),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleLarge),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
