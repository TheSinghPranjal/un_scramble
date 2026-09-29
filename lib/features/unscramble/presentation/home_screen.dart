import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/prefs/preferences.dart';
import '../../../shared/theme/app_theme.dart';
import '../application/unscramble_controller.dart';
import '../data/word_repository.dart';
import '../domain/models.dart';
import 'game_screen.dart';
import 'widgets/letter_tile_face.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _starting = false;

  Future<void> _play() async {
    setState(() => _starting = true);
    final controller = ref.read(unscrambleControllerProvider.notifier);
    await controller.startNewGame();
    if (!mounted) return;
    setState(() => _starting = false);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const GameScreen()));
    // Any exit from the game (close button, back, "Home") lands here. Only
    // freeze the clock: resetting now would blank the screen mid-transition.
    // The next startNewGame() resets everything.
    controller.pauseTimer(TimerPauseReason.leftGameScreen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GameColors.of(context);
    final words = ref.watch(wordListProvider);
    final highScore = ref.watch(highScoreProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Logo(),
                    const SizedBox(height: 12),
                    Text(
                      'Rebuild the word before your lives run out.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _HighScore(score: highScore),
                    const SizedBox(height: 20),
                    const _HowToCard(),
                    const SizedBox(height: 28),
                    words.when(
                      data: (_) =>
                          FilledButton.icon(
                                onPressed: _starting ? null : _play,
                                icon: _starting
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 28,
                                      ),
                                label: const Text('Play'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(60),
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scaleXY(
                                end: 1.03,
                                duration: 1200.ms,
                                curve: Curves.easeInOut,
                              ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Column(
                        children: [
                          Text(
                            "Couldn't load words.",
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          TextButton(
                            onPressed: () => ref.invalidate(wordListProvider),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Unscramble',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 4.0;
          final size = math.min(
            40.0,
            (constraints.maxWidth - gap * (kMaxLives - 1)) / kMaxLives,
          );
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < lifeLetters.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                LetterTileFace(
                      char: lifeLetters[i],
                      width: size,
                      height: size * 1.2,
                      tone: TileTone.locked,
                    )
                    .animate(delay: (60 * i).ms)
                    .fadeIn(duration: 250.ms)
                    .slideY(begin: -0.8, curve: Curves.easeOutBack)
                    .then(delay: 200.ms)
                    .shimmer(duration: 900.ms),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HighScore extends StatelessWidget {
  const _HighScore({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.emoji_events_rounded, color: GameColors.of(context).warning),
        const SizedBox(width: 8),
        Text('Best score  ', style: theme.textTheme.titleMedium),
        Text('$score', style: theme.textTheme.titleLarge),
      ],
    );
  }
}

class _HowToCard extends StatelessWidget {
  const _HowToCard();

  static const _steps = [
    (
      Icons.touch_app_rounded,
      'Drag — or tap — the scrambled letters into the slots to rebuild the word.',
    ),
    (
      Icons.favorite_rounded,
      'A wrong letter costs a life. You get 10 — one for each letter of UNSCRAMBLE.',
    ),
    (
      Icons.timer_rounded,
      'Beat the 2:00 clock. Two mistakes unlock a free hint.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to play', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final (icon, text) in _steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 22, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(text, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
