import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/prefs/preferences.dart';
import '../../../shared/theme/art_palette.dart';
import '../application/unscramble_controller.dart';
import '../domain/models.dart';
import 'widgets/answer_slots_row.dart';
import 'widgets/art_decor.dart';
import 'widgets/coach_marks.dart';
import 'widgets/hint_widgets.dart';
import 'widgets/letter_tray.dart';
import 'widgets/result_dialog.dart';
import 'widgets/timer_hud.dart';
import 'widgets/unscramble_life_bar.dart';

/// Game artwork: pastel sky with cloud banks along the edges.
const _backgroundAsset = 'assets/images/game_background.png';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  final _slotsKey = GlobalKey();
  final _trayKey = GlobalKey();
  bool _showCoachMarks = false;

  UnscrambleController get _controller =>
      ref.read(unscrambleControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!ref.read(coachMarksSeenProvider)) {
      _showCoachMarks = true;
      _controller.pauseTimer(TimerPauseReason.coachMarks);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _controller.pauseTimer(TimerPauseReason.appLifecycle);
      case AppLifecycleState.resumed:
        _controller.resumeTimer(TimerPauseReason.appLifecycle);
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _finishCoachMarks() {
    ref.read(coachMarksSeenProvider.notifier).markSeen();
    setState(() => _showCoachMarks = false);
    _controller.resumeTimer(TimerPauseReason.coachMarks);
  }

  void _onStateChanged(UnscrambleGameState? prev, UnscrambleGameState next) {
    final event = next.lastEvent;
    if (event != null && event.serial != prev?.lastEvent?.serial) {
      switch (event.type) {
        case GameEventType.correct:
          HapticFeedback.mediumImpact();
        case GameEventType.wrong:
          HapticFeedback.heavyImpact();
        case GameEventType.hint:
          HapticFeedback.selectionClick();
      }
    }

    if (prev?.status == next.status) return;
    switch (next.status) {
      case GameStatus.pausedForHint:
        _showHintSheet();
      case GameStatus.won:
      case GameStatus.lostLives:
      case GameStatus.lostTimeout:
        _showResult();
      case GameStatus.idle:
      case GameStatus.playing:
        break;
    }
  }

  Future<void> _showHintSheet() async {
    // Short beat so the rejected tile finishes flying home first.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final state = ref.read(unscrambleControllerProvider);
    if (state.status != GameStatus.pausedForHint) return;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      builder: (sheetContext) => HintSheet(
        category: state.category,
        clue: state.hintText,
        onReveal: () {
          Navigator.pop(sheetContext);
          _controller.useHint();
        },
        onNoThanks: () => Navigator.pop(sheetContext),
      ),
    );
    // Any close path (button, swipe, barrier tap, back) resumes the round.
    if (mounted) _controller.dismissHintSheet();
  }

  Future<void> _showResult() async {
    // Let the final snap / shake animation land before the dialog.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final state = ref.read(unscrambleControllerProvider);
    if (!state.status.isOver) return;
    if (state.status == GameStatus.won) HapticFeedback.heavyImpact();

    await showResultDialog(
      context,
      state: state,
      onNext: () {
        Navigator.pop(context);
        _controller.nextRound();
      },
      onRetry: () {
        Navigator.pop(context);
        _controller.retryRound();
      },
      onHome: () {
        Navigator.pop(context); // dialog
        Navigator.pop(context); // game screen
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(unscrambleControllerProvider, _onStateChanged);
    final status = ref.watch(
      unscrambleControllerProvider.select((s) => s.status),
    );

    return Theme(
      data: ArtPalette.theme,
      child: Scaffold(
        floatingActionButton: const HintButton(),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _backgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              excludeFromSemantics: true,
            ),
            const _BackgroundStars(),
            SafeArea(
              child: status == GameStatus.idle
                  ? const Center(child: CircularProgressIndicator())
                  : _GameBody(slotsKey: _slotsKey, trayKey: _trayKey),
            ),
            if (_showCoachMarks && status != GameStatus.idle)
              Positioned.fill(
                child: CoachMarksOverlay(
                  onDone: _finishCoachMarks,
                  steps: [
                    CoachStep(
                      target: _trayKey,
                      title: 'Your scrambled letters',
                      body:
                          'Drag a letter — or just tap it to drop it in the next empty slot.',
                    ),
                    CoachStep(
                      target: _slotsKey,
                      title: 'Rebuild the word here',
                      body:
                          'Each slot wants one exact letter. A wrong letter bounces '
                          'back and costs a life from UNSCRAMBLE.',
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

/// Stars floating over the painted clouds, placed as fractions of the screen
/// so they sit on the cloud banks at any size. Drawn behind the game UI.
class _BackgroundStars extends StatelessWidget {
  const _BackgroundStars();

  static const _stars = [
    // (x, y, size, tilt) — x/y are fractions of the screen.
    (0.14, 0.27, 44.0, -0.04),
    (0.84, 0.32, 32.0, 0.06),
    (0.10, 0.81, 50.0, 0.03),
    (0.82, 0.90, 42.0, -0.05),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          for (final (x, y, size, turns) in _stars)
            Positioned(
              left: constraints.maxWidth * x - size / 2,
              top: constraints.maxHeight * y - size / 2,
              child: ArtStar(size: size, turns: turns),
            ),
        ],
      ),
    );
  }
}

class _GameBody extends StatelessWidget {
  const _GameBody({required this.slotsKey, required this.trayKey});

  final GlobalKey slotsKey;
  final GlobalKey trayKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: _TopBar(),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: UnscrambleLifeBar(),
        ),
        const SizedBox(height: 16),
        const _CategoryChip(),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SlotsCard(
                  child: KeyedSubtree(
                    key: slotsKey,
                    child: const AnswerSlotsRow(),
                  ),
                ),
                const SizedBox(height: 16),
                const _InstructionLine(),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.6),
                  Colors.white.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(36),
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
            child: SingleChildScrollView(
              // Extra bottom padding keeps tiles clear of the hint FAB.
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 88),
              child: Column(
                children: [
                  KeyedSubtree(key: trayKey, child: const LetterTray()),
                  const SizedBox(height: 28),
                  const _ShuffleButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Frosted panel behind the answer slots, with yellow "pop" rays on its top
/// corners.
class _SlotsCard extends StatelessWidget {
  const _SlotsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: ArtPalette.purple.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
        const Positioned(left: -18, top: -20, child: SparkRays(mirrored: true)),
        const Positioned(right: -18, top: -20, child: SparkRays()),
      ],
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final round = ref.watch(
      unscrambleControllerProvider.select((s) => s.roundIndex),
    );
    final score = ref.watch(
      unscrambleControllerProvider.select((s) => s.score),
    );
    return Row(
      children: [
        IconButton(
          tooltip: 'Home',
          color: ArtPalette.ink,
          iconSize: 30,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unscramble',
                style: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ArtPalette.purple,
                ),
              ),
              Text(
                'Round $round · $score pts',
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ArtPalette.ink,
                ),
              ),
            ],
          ),
        ),
        const TimerHud(),
      ],
    );
  }
}

class _CategoryChip extends ConsumerWidget {
  const _CategoryChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(
      unscrambleControllerProvider.select((s) => s.category),
    );
    final difficulty = ref.watch(
      unscrambleControllerProvider.select((s) => s.difficulty),
    );
    final length = ref.watch(
      unscrambleControllerProvider.select((s) => s.targetWord.length),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: BoxDecoration(
        color: ArtPalette.lavenderDeep.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$category · ${difficulty.label} · $length letters',
        style: GoogleFonts.nunito(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ArtPalette.ink.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _InstructionLine extends ConsumerWidget {
  const _InstructionLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(
      unscrambleControllerProvider.select((s) => s.hasPlacedAnyLetter),
    );
    return AnimatedOpacity(
      opacity: hidden ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: Text(
        'Drag letters into the slots',
        style: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: ArtPalette.muted,
        ),
      ).animate().fadeIn(delay: 300.ms),
    );
  }
}

class _ShuffleButton extends ConsumerWidget {
  const _ShuffleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      unscrambleControllerProvider.select(
        (s) => s.status == GameStatus.playing && s.tray.length > 1,
      ),
    );
    return TextButton.icon(
      onPressed: enabled
          ? ref.read(unscrambleControllerProvider.notifier).shuffleTray
          : null,
      icon: const Icon(Icons.shuffle_rounded, size: 28),
      label: const Text('Shuffle'),
      style: TextButton.styleFrom(
        foregroundColor: ArtPalette.purple,
        disabledForegroundColor: ArtPalette.muted,
        backgroundColor: ArtPalette.lavenderDeep.withValues(alpha: 0.75),
        disabledBackgroundColor: ArtPalette.lavenderDeep.withValues(alpha: 0.4),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        textStyle: GoogleFonts.fredoka(
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
