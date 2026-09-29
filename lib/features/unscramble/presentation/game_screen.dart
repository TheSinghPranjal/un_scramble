import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/prefs/preferences.dart';
import '../../../shared/theme/app_theme.dart';
import '../application/unscramble_controller.dart';
import '../domain/models.dart';
import 'widgets/answer_slots_row.dart';
import 'widgets/coach_marks.dart';
import 'widgets/hint_widgets.dart';
import 'widgets/letter_tray.dart';
import 'widgets/result_dialog.dart';
import 'widgets/timer_hud.dart';
import 'widgets/unscramble_life_bar.dart';

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
    final colors = GameColors.of(context);
    final status = ref.watch(
      unscrambleControllerProvider.select((s) => s.status),
    );

    return Scaffold(
      floatingActionButton: const HintButton(),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: Stack(
          children: [
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

class _GameBody extends StatelessWidget {
  const _GameBody({required this.slotsKey, required this.trayKey});

  final GlobalKey slotsKey;
  final GlobalKey trayKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 16, 0),
          child: _TopBar(),
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: UnscrambleLifeBar(),
        ),
        const SizedBox(height: 14),
        const _CategoryChip(),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KeyedSubtree(key: slotsKey, child: const AnswerSlotsRow()),
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
            decoration: BoxDecoration(
              color: scheme.surfaceContainer.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: SingleChildScrollView(
              // Extra bottom padding keeps tiles clear of the hint FAB.
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 88),
              child: Column(
                children: [
                  KeyedSubtree(key: trayKey, child: const LetterTray()),
                  const SizedBox(height: 16),
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

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unscramble',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Round $round · $score pts',
                style: theme.textTheme.titleMedium,
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
    final theme = Theme.of(context);
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$category · ${difficulty.label} · $length letters',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
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
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: hidden ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: Text(
        'Drag letters into the slots',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
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
      icon: const Icon(Icons.shuffle_rounded),
      label: const Text('Shuffle'),
    );
  }
}
