import 'package:flutter/foundation.dart';

/// Number of lives per round. Must equal [lifeLetters].length — each life is
/// rendered as one letter of the brand word.
const int kMaxLives = 10;

/// Round length in seconds (2 minutes).
const int kRoundSeconds = 120;

/// The brand life bar. Lives are lost from LEFT to right: U, then N, then S…
const List<String> lifeLetters = [
  'U',
  'N',
  'S',
  'C',
  'R',
  'A',
  'M',
  'B',
  'L',
  'E',
];

/// After this many lives are lost in a round, the one-time hint sheet appears.
const int kLivesLostBeforeHint = 2;

enum Difficulty {
  easy,
  medium,
  hard;

  static Difficulty parse(String? raw) => Difficulty.values.firstWhere(
    (d) => d.name == raw?.toLowerCase(),
    orElse: () => Difficulty.easy,
  );

  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
}

/// One entry of `assets/words/words.json`.
@immutable
class WordEntry {
  const WordEntry({
    required this.word,
    required this.category,
    this.hintText,
    this.difficulty = Difficulty.easy,
  });

  factory WordEntry.fromJson(Map<String, dynamic> json) => WordEntry(
    word: (json['word'] as String).trim().toUpperCase(),
    category: json['category'] as String? ?? 'General',
    hintText: json['hintText'] as String?,
    difficulty: Difficulty.parse(json['difficulty'] as String?),
  );

  static final RegExp validWord = RegExp(r'^[A-Z]{4,8}$');

  final String word;
  final String category;
  final String? hintText;
  final Difficulty difficulty;

  bool get isValid => validWord.hasMatch(word);
}

/// A single draggable letter. The [id] is unique per round so duplicate
/// letters (e.g. the two Ls in HELLO) are tracked independently.
@immutable
class LetterTile {
  const LetterTile({required this.id, required this.char});

  final String id;
  final String char;

  @override
  bool operator ==(Object other) => other is LetterTile && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LetterTile($char#$id)';
}

enum GameStatus {
  idle,
  playing,
  pausedForHint,
  won,
  lostLives,
  lostTimeout;

  bool get isOver => this == won || this == lostLives || this == lostTimeout;
  bool get isLost => this == lostLives || this == lostTimeout;
}

/// Result of attempting to put a tile into a slot.
enum DropResult {
  /// Correct letter: the slot is now locked.
  accepted,

  /// Wrong letter: one life lost, slot unchanged.
  rejected,

  /// Nothing happened (slot locked, game not running, stale tile…). No penalty.
  ignored,
}

enum GameEventType { correct, wrong, hint }

/// One-shot feedback event for the UI (animations + haptics). [serial] grows
/// monotonically so widgets can tell a new event from a repeated one.
@immutable
class GameEvent {
  const GameEvent({
    required this.type,
    required this.serial,
    this.slotIndex,
    this.tileId,
  });

  final GameEventType type;
  final int serial;
  final int? slotIndex;
  final String? tileId;
}

@immutable
class UnscrambleGameState {
  const UnscrambleGameState({
    required this.targetWord,
    required this.category,
    required this.difficulty,
    required this.hintText,
    required this.tray,
    required this.slots,
    required this.livesRemaining,
    required this.secondsRemaining,
    required this.hintUnlocked,
    required this.hintUsed,
    required this.hintSheetShownThisRound,
    required this.status,
    required this.roundIndex,
    required this.score,
    required this.lastRoundScore,
    required this.lastEvent,
  });

  factory UnscrambleGameState.initial() => const UnscrambleGameState(
    targetWord: '',
    category: '',
    difficulty: Difficulty.easy,
    hintText: null,
    tray: [],
    slots: [],
    livesRemaining: kMaxLives,
    secondsRemaining: kRoundSeconds,
    hintUnlocked: false,
    hintUsed: false,
    hintSheetShownThisRound: false,
    status: GameStatus.idle,
    roundIndex: 0,
    score: 0,
    lastRoundScore: 0,
    lastEvent: null,
  );

  /// Uppercase A–Z only. Never rendered on the playing screen.
  final String targetWord;
  final String category;
  final Difficulty difficulty;
  final String? hintText;

  /// Letters still available to place, in display order.
  final List<LetterTile> tray;

  /// One entry per target letter. `null` = empty; non-null = locked correct
  /// letter (wrong letters never stay in a slot).
  final List<String?> slots;

  final int livesRemaining;
  final int secondsRemaining;
  final bool hintUnlocked;
  final bool hintUsed;
  final bool hintSheetShownThisRound;
  final GameStatus status;
  final int roundIndex;
  final int score;

  /// Points earned by the most recently won round (for the win dialog).
  final int lastRoundScore;
  final GameEvent? lastEvent;

  int get livesLost => kMaxLives - livesRemaining;
  bool get isBoardComplete => slots.isNotEmpty && slots.every((s) => s != null);
  bool get hasPlacedAnyLetter => slots.any((s) => s != null);
  int get firstEmptySlot => slots.indexWhere((s) => s == null);

  /// Hint button is visible once unlocked and until the free hint is spent.
  bool get canUseHint => hintUnlocked && !hintUsed && !status.isOver;

  UnscrambleGameState copyWith({
    String? targetWord,
    String? category,
    Difficulty? difficulty,
    String? hintText,
    bool clearHintText = false,
    List<LetterTile>? tray,
    List<String?>? slots,
    int? livesRemaining,
    int? secondsRemaining,
    bool? hintUnlocked,
    bool? hintUsed,
    bool? hintSheetShownThisRound,
    GameStatus? status,
    int? roundIndex,
    int? score,
    int? lastRoundScore,
    GameEvent? lastEvent,
    bool clearLastEvent = false,
  }) {
    return UnscrambleGameState(
      targetWord: targetWord ?? this.targetWord,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      hintText: clearHintText ? null : (hintText ?? this.hintText),
      tray: tray ?? this.tray,
      slots: slots ?? this.slots,
      livesRemaining: livesRemaining ?? this.livesRemaining,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      hintUnlocked: hintUnlocked ?? this.hintUnlocked,
      hintUsed: hintUsed ?? this.hintUsed,
      hintSheetShownThisRound:
          hintSheetShownThisRound ?? this.hintSheetShownThisRound,
      status: status ?? this.status,
      roundIndex: roundIndex ?? this.roundIndex,
      score: score ?? this.score,
      lastRoundScore: lastRoundScore ?? this.lastRoundScore,
      lastEvent: clearLastEvent ? null : (lastEvent ?? this.lastEvent),
    );
  }
}
