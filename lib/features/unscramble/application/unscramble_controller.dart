import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/prefs/preferences.dart';
import '../../../shared/sfx/sfx_player.dart';
import '../data/word_repository.dart';
import '../domain/models.dart';

/// Randomness source; override with a seeded [Random] in tests.
final randomProvider = Provider<Random>((ref) => Random());

/// Whether the controller drives its own 1-second ticker. Tests set this to
/// false and call [UnscrambleController.tickTimer] manually.
final autoTickProvider = Provider<bool>((ref) => true);

/// Independent reasons the countdown may be held. The ticker only runs when
/// the game is `playing` AND no reason is active, so e.g. returning from the
/// background while the coach marks are open does not restart the clock.
enum TimerPauseReason { appLifecycle, coachMarks, leftGameScreen }

final unscrambleControllerProvider =
    NotifierProvider<UnscrambleController, UnscrambleGameState>(
      UnscrambleController.new,
    );

/// Lives as 10 booleans, one per UNSCRAMBLE letter. Lives are lost from the
/// LEFT: with 8 lives, indices 0 (U) and 1 (N) are dead.
final lifeLettersProvider = Provider<List<bool>>((ref) {
  final lives = ref.watch(
    unscrambleControllerProvider.select((s) => s.livesRemaining),
  );
  final lostCount = kMaxLives - lives;
  return List<bool>.generate(kMaxLives, (i) => i >= lostCount);
});

/// 1.0 at round start → 0.0 at timeout.
final timerProgressProvider = Provider<double>((ref) {
  final seconds = ref.watch(
    unscrambleControllerProvider.select((s) => s.secondsRemaining),
  );
  return seconds / kRoundSeconds;
});

class UnscrambleController extends Notifier<UnscrambleGameState> {
  static const _uuid = Uuid();

  Timer? _ticker;
  final Set<TimerPauseReason> _pauseReasons = {};
  WordDeck? _deck;
  WordEntry? _currentEntry;
  int _eventSerial = 0;

  @override
  UnscrambleGameState build() {
    ref.onDispose(_stopTicker);
    return UnscrambleGameState.initial();
  }

  Random get _random => ref.read(randomProvider);
  SfxPlayer get _sfx => ref.read(sfxPlayerProvider);

  // ---------------------------------------------------------------------------
  // Round lifecycle
  // ---------------------------------------------------------------------------

  /// Starts a fresh session from the home screen: score resets, round 1.
  Future<void> startNewGame() async {
    resetToHome();
    await nextRound();
  }

  /// Deals the next unused word from the deck and starts it.
  Future<void> nextRound() async {
    final words = await ref.read(wordListProvider.future);
    if (!ref.mounted) return;
    final deck = _deck ??= WordDeck(words, _random);
    final entry = deck.next();
    state = state.copyWith(roundIndex: state.roundIndex + 1);
    startRound(
      word: entry.word,
      category: entry.category,
      hintText: entry.hintText,
      difficulty: entry.difficulty,
    );
  }

  /// Replays the current word with a fresh shuffle. Score is kept.
  void retryRound() {
    final entry = _currentEntry;
    if (entry == null) return;
    startRound(
      word: entry.word,
      category: entry.category,
      hintText: entry.hintText,
      difficulty: entry.difficulty,
    );
  }

  void startRound({
    required String word,
    required String category,
    String? hintText,
    Difficulty difficulty = Difficulty.easy,
  }) {
    final target = word.trim().toUpperCase();
    assert(RegExp(r'^[A-Z]+$').hasMatch(target), 'Invalid target word: $word');
    _currentEntry = WordEntry(
      word: target,
      category: category,
      hintText: hintText,
      difficulty: difficulty,
    );

    final tiles = [
      for (final char in target.split(''))
        LetterTile(id: _uuid.v4(), char: char),
    ];

    state = state.copyWith(
      targetWord: target,
      category: category,
      difficulty: difficulty,
      hintText: hintText,
      clearHintText: hintText == null,
      tray: _scramble(tiles, target),
      slots: List<String?>.filled(target.length, null),
      livesRemaining: kMaxLives,
      secondsRemaining: kRoundSeconds,
      hintUnlocked: false,
      hintUsed: false,
      hintSheetShownThisRound: false,
      status: GameStatus.playing,
      clearLastEvent: true,
    );
    _syncTicker();
  }

  /// Reshuffles the remaining tray tiles (no penalty).
  void shuffleTray() {
    if (state.status != GameStatus.playing) return;
    final remainingTarget = [
      for (var i = 0; i < state.slots.length; i++)
        if (state.slots[i] == null) state.targetWord[i],
    ].join();
    state = state.copyWith(tray: _scramble(state.tray, remainingTarget));
  }

  void resetToHome() {
    _stopTicker();
    _pauseReasons.clear();
    _currentEntry = null;
    state = UnscrambleGameState.initial();
  }

  // ---------------------------------------------------------------------------
  // Player actions
  // ---------------------------------------------------------------------------

  /// Core rule: a dropped letter is checked against the letter expected at
  /// THAT slot. Right → slot locks. Wrong → letter never stays, costs 1 life.
  DropResult onLetterDropped({
    required LetterTile tile,
    required int slotIndex,
  }) {
    if (state.status != GameStatus.playing) return DropResult.ignored;
    if (slotIndex < 0 || slotIndex >= state.slots.length) {
      return DropResult.ignored;
    }
    // Rule 5: a locked slot can't be overwritten, and costs nothing to try.
    if (state.slots[slotIndex] != null) return DropResult.ignored;
    // Guards against a stale drag of a tile that was consumed meanwhile
    // (e.g. by a hint) — rapid drags must never double-place a letter.
    if (!state.tray.contains(tile)) return DropResult.ignored;

    if (tile.char == state.targetWord[slotIndex]) {
      _place(tile: tile, slotIndex: slotIndex, type: GameEventType.correct);
      _sfx.playCorrect();
      return DropResult.accepted;
    }

    _loseLife(slotIndex: slotIndex, tileId: tile.id);
    return DropResult.rejected;
  }

  /// Tap-to-place: targets the first empty slot with the SAME validation, so
  /// a wrong tap still costs a life.
  DropResult onLetterTappedFromTray(LetterTile tile) {
    final index = state.firstEmptySlot;
    if (index < 0) return DropResult.ignored;
    return onLetterDropped(tile: tile, slotIndex: index);
  }

  /// Opens the hint sheet manually via the hint button.
  void openHintSheet() {
    if (state.status != GameStatus.playing || !state.canUseHint) return;
    state = state.copyWith(status: GameStatus.pausedForHint);
    _syncTicker();
  }

  /// Reveals the leftmost empty slot. Free (no life cost), once per round.
  void useHint() {
    final status = state.status;
    if (status != GameStatus.playing && status != GameStatus.pausedForHint) {
      return;
    }
    if (!state.canUseHint) return;
    final index = state.firstEmptySlot;
    if (index < 0) return;

    final expected = state.targetWord[index];
    final tile = state.tray.firstWhere((t) => t.char == expected);
    state = state.copyWith(hintUsed: true, status: GameStatus.playing);
    _place(tile: tile, slotIndex: index, type: GameEventType.hint);
    _syncTicker();
  }

  /// Called whenever the hint sheet closes — resumes play even if the hint
  /// wasn't used.
  void dismissHintSheet() {
    if (state.status != GameStatus.pausedForHint) return;
    state = state.copyWith(status: GameStatus.playing);
    _syncTicker();
  }

  // ---------------------------------------------------------------------------
  // Timer
  // ---------------------------------------------------------------------------

  void tickTimer() {
    if (state.status != GameStatus.playing) return;
    final next = state.secondsRemaining - 1;
    if (next <= 0) {
      state = state.copyWith(
        secondsRemaining: 0,
        status: GameStatus.lostTimeout,
      );
      _stopTicker();
      _sfx.playLose();
      return;
    }
    state = state.copyWith(secondsRemaining: next);
    if (next <= 10) _sfx.playTick();
  }

  void pauseTimer([TimerPauseReason reason = TimerPauseReason.appLifecycle]) {
    _pauseReasons.add(reason);
    _syncTicker();
  }

  void resumeTimer([TimerPauseReason reason = TimerPauseReason.appLifecycle]) {
    _pauseReasons.remove(reason);
    _syncTicker();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _place({
    required LetterTile tile,
    required int slotIndex,
    required GameEventType type,
  }) {
    final slots = [...state.slots]..[slotIndex] = tile.char;
    state = state.copyWith(
      tray: state.tray.where((t) => t != tile).toList(growable: false),
      slots: List.unmodifiable(slots),
      lastEvent: _event(type, slotIndex: slotIndex, tileId: tile.id),
    );
    if (state.isBoardComplete) _win();
  }

  void _loseLife({required int slotIndex, required String tileId}) {
    final lives = state.livesRemaining - 1;
    var next = state.copyWith(
      livesRemaining: lives,
      lastEvent: _event(
        GameEventType.wrong,
        slotIndex: slotIndex,
        tileId: tileId,
      ),
    );
    _sfx.playWrong();

    if (lives <= 0) {
      next = next.copyWith(livesRemaining: 0, status: GameStatus.lostLives);
      _sfx.playLose();
    } else if (next.livesLost >= kLivesLostBeforeHint &&
        !next.hintSheetShownThisRound) {
      // Exactly once per round: unlock the hint and pause for the sheet. The
      // UI listens for the `pausedForHint` transition to present it.
      next = next.copyWith(
        hintUnlocked: true,
        hintSheetShownThisRound: true,
        status: GameStatus.pausedForHint,
      );
    }
    state = next;
    _syncTicker();
  }

  void _win() {
    final roundScore =
        50 +
        state.targetWord.length * 10 +
        state.secondsRemaining +
        state.livesRemaining * 5;
    state = state.copyWith(
      status: GameStatus.won,
      score: state.score + roundScore,
      lastRoundScore: roundScore,
    );
    _stopTicker();
    _sfx.playWin();
    ref.read(highScoreProvider.notifier).submit(state.score);
  }

  GameEvent _event(GameEventType type, {int? slotIndex, String? tileId}) =>
      GameEvent(
        type: type,
        serial: ++_eventSerial,
        slotIndex: slotIndex,
        tileId: tileId,
      );

  /// Shuffles [tiles] so their letters never spell [target] (when possible).
  List<LetterTile> _scramble(List<LetterTile> tiles, String target) {
    final shuffled = [...tiles];
    // A word like "AAAA" (or a single remaining letter) can't be scrambled.
    final canScramble = target.split('').toSet().length > 1;
    for (var attempt = 0; attempt < 20; attempt++) {
      shuffled.shuffle(_random);
      if (!canScramble || shuffled.map((t) => t.char).join() != target) break;
    }
    // Astronomically unlikely fallback: rotate by one, which always differs
    // from the target when at least two distinct letters exist.
    if (canScramble && shuffled.map((t) => t.char).join() == target) {
      shuffled.add(shuffled.removeAt(0));
    }
    return List.unmodifiable(shuffled);
  }

  void _syncTicker() {
    final shouldRun =
        ref.read(autoTickProvider) &&
        state.status == GameStatus.playing &&
        _pauseReasons.isEmpty;
    if (shouldRun) {
      _ticker ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => tickTimer(),
      );
    } else {
      _stopTicker();
    }
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}
