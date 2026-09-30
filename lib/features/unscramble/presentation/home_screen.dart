import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/prefs/preferences.dart';
import '../../../shared/theme/art_palette.dart';
import '../application/unscramble_controller.dart';
import '../data/word_repository.dart';
import 'game_screen.dart';

/// Home artwork, with the UNSCRAMBLE logo painted into its top section.
const _backgroundAsset = 'assets/images/home_background.png';
const _backgroundSize = Size(884, 1779);

/// Where the painted logo ends, as a fraction of the artwork's height.
const _logoBottomFraction = 0.27;

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
    final words = ref.watch(wordListProvider);
    final highScore = ref.watch(highScoreProvider);
    final media = MediaQuery.of(context);

    // The artwork is laid out with BoxFit.cover anchored to the top, so its
    // rendered scale is the larger of the two axis ratios. Start the content
    // just below where the painted logo lands.
    final scale = math.max(
      media.size.width / _backgroundSize.width,
      media.size.height / _backgroundSize.height,
    );
    final logoBottom = _backgroundSize.height * _logoBottomFraction * scale;
    final topInset = math.max(0.0, logoBottom - media.padding.top) + 8;

    return Theme(
      data: ArtPalette.theme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _backgroundAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  excludeFromSemantics: true,
                ),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, topInset, 20, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // The logo is part of the artwork; keep it
                            // announced as the screen's heading.
                            Semantics(
                              header: true,
                              label: 'Unscramble',
                              child: const SizedBox.shrink(),
                            ),
                            Text(
                              'Rebuild the word before your lives run out.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: ArtPalette.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(child: _HighScore(score: highScore)),
                            const SizedBox(height: 20),
                            const _HowToCard(),
                            const SizedBox(height: 24),
                            words.when(
                              data: (_) =>
                                  _PlayButton(
                                        busy: _starting,
                                        onPressed: _starting ? null : _play,
                                      )
                                      .animate(
                                        onPlay: (c) => c.repeat(reverse: true),
                                      )
                                      .scaleXY(
                                        end: 1.03,
                                        duration: 1200.ms,
                                        curve: Curves.easeInOut,
                                      ),
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (error, _) => Column(
                                children: [
                                  Text(
                                    "Couldn't load words.",
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        ref.invalidate(wordListProvider),
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
              ],
            ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ArtPalette.lavender.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: ArtPalette.gold,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Best score',
              style: theme.textTheme.titleMedium?.copyWith(
                color: ArtPalette.ink,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '$score',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: ArtPalette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  const _HowToCard();

  static const _steps = [
    (
      Icons.touch_app_rounded,
      ArtPalette.purple,
      ArtPalette.lavender,
      'Drag — or tap — the scrambled letters into the slots to rebuild the word.',
    ),
    (
      Icons.favorite_rounded,
      ArtPalette.heart,
      ArtPalette.pink,
      'A wrong letter costs a life. You get 10 — one for each letter of UNSCRAMBLE.',
    ),
    (
      Icons.timer_rounded,
      ArtPalette.purple,
      ArtPalette.lavender,
      'Beat the 2:00 clock. Two mistakes unlock a free hint.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: ArtPalette.purple.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'How to play',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: ArtPalette.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, (icon, iconColor, badgeColor, text))
                in _steps.indexed) ...[
              if (i > 0) const Divider(height: 1, color: ArtPalette.divider),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: 60,
                        child: Icon(icon, size: 32, color: iconColor),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: ArtPalette.ink,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(28);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ArtPalette.purpleLight, ArtPalette.purple],
        ),
        boxShadow: [
          BoxShadow(
            color: ArtPalette.purple.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.play_arrow_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                const SizedBox(width: 10),
                Text(
                  'Play',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
