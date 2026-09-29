import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:un_scramble/features/unscramble/application/unscramble_controller.dart';
import 'package:un_scramble/features/unscramble/domain/models.dart';
import 'package:un_scramble/shared/prefs/preferences.dart';

void main() {
  late ProviderContainer container;
  late UnscrambleController controller;

  UnscrambleGameState state() => container.read(unscrambleControllerProvider);

  /// Any tray tile carrying [char] (first match).
  LetterTile tileFor(String char) =>
      state().tray.firstWhere((t) => t.char == char);

  /// A tray tile whose letter is NOT what [slotIndex] expects.
  LetterTile wrongTileFor(int slotIndex) =>
      state().tray.firstWhere((t) => t.char != state().targetWord[slotIndex]);

  /// Drops a wrong letter on the first empty slot [count] times.
  void loseLives(int count) {
    for (var i = 0; i < count; i++) {
      final slot = state().firstEmptySlot;
      controller.onLetterDropped(tile: wrongTileFor(slot), slotIndex: slot);
      controller.dismissHintSheet(); // the hint pause would block later drops
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        autoTickProvider.overrideWithValue(false),
        randomProvider.overrideWithValue(Random(42)),
      ],
    );
    addTearDown(container.dispose);
    controller = container.read(unscrambleControllerProvider.notifier);
    controller.startRound(word: 'TIGER', category: 'Animals');
  });

  test('1. correct drop locks the slot and does not change lives', () {
    final result = controller.onLetterDropped(tile: tileFor('T'), slotIndex: 0);

    expect(result, DropResult.accepted);
    expect(state().slots[0], 'T');
    expect(state().livesRemaining, kMaxLives);
    expect(state().tray.map((t) => t.char), isNot(contains('T')));
    expect(state().tray, hasLength(4));
  });

  test('2. wrong drop costs exactly one life and leaves the slot empty', () {
    final result = controller.onLetterDropped(tile: tileFor('I'), slotIndex: 0);

    expect(result, DropResult.rejected);
    expect(state().slots[0], isNull);
    expect(state().livesRemaining, kMaxLives - 1);
    expect(state().tray, hasLength(5), reason: 'rejected tile returns to tray');
  });

  test('3. duplicate letters are tracked independently by tile id', () {
    controller.startRound(word: 'HELLO', category: 'Test');
    final ls = state().tray.where((t) => t.char == 'L').toList();
    expect(ls, hasLength(2));
    expect(ls[0].id, isNot(ls[1].id));

    expect(
      controller.onLetterDropped(tile: ls[1], slotIndex: 3),
      DropResult.accepted,
    );
    // The same tile can't be placed twice…
    expect(
      controller.onLetterDropped(tile: ls[1], slotIndex: 2),
      DropResult.ignored,
    );
    // …but its twin can fill the other L slot.
    expect(
      controller.onLetterDropped(tile: ls[0], slotIndex: 2),
      DropResult.accepted,
    );
    expect(state().slots, [null, null, 'L', 'L', null]);
    expect(state().livesRemaining, kMaxLives);
  });

  test('4. losing 2 lives unlocks the hint and pauses for the sheet once', () {
    controller.onLetterDropped(tile: wrongTileFor(0), slotIndex: 0);
    expect(state().hintUnlocked, isFalse);
    expect(state().status, GameStatus.playing);

    controller.onLetterDropped(tile: wrongTileFor(0), slotIndex: 0);
    expect(state().livesRemaining, 8);
    expect(state().hintUnlocked, isTrue);
    expect(state().hintSheetShownThisRound, isTrue);
    expect(state().status, GameStatus.pausedForHint);

    // Drops are ignored while the sheet is up.
    expect(
      controller.onLetterDropped(tile: wrongTileFor(0), slotIndex: 0),
      DropResult.ignored,
    );

    controller.dismissHintSheet();
    expect(state().status, GameStatus.playing);

    // A third mistake does not re-open the sheet automatically.
    controller.onLetterDropped(tile: wrongTileFor(0), slotIndex: 0);
    expect(state().status, GameStatus.playing);
    expect(state().livesRemaining, 7);
  });

  test('5. useHint fills the leftmost empty slot without costing a life', () {
    controller.onLetterDropped(tile: tileFor('T'), slotIndex: 0);
    loseLives(2);
    expect(state().canUseHint, isTrue);

    controller.useHint();

    expect(state().slots, ['T', 'I', null, null, null]);
    expect(state().hintUsed, isTrue);
    expect(state().canUseHint, isFalse);
    expect(state().livesRemaining, 8);
    expect(state().tray.map((t) => t.char), isNot(contains('I')));

    // Only one free hint per round.
    controller.useHint();
    expect(state().slots[2], isNull);
  });

  test('6. timer reaching 0 ends the round as lostTimeout', () {
    for (var i = 0; i < kRoundSeconds - 1; i++) {
      controller.tickTimer();
    }
    expect(state().secondsRemaining, 1);
    expect(state().status, GameStatus.playing);

    controller.tickTimer();
    expect(state().secondsRemaining, 0);
    expect(state().status, GameStatus.lostTimeout);
    expect(
      state().livesRemaining,
      kMaxLives,
      reason: 'timeout loses with lives left',
    );
  });

  test('7. filling every slot wins the round and scores it', () {
    const word = 'TIGER';
    for (var i = 0; i < word.length; i++) {
      controller.onLetterDropped(tile: tileFor(word[i]), slotIndex: i);
    }
    expect(state().status, GameStatus.won);
    expect(state().isBoardComplete, isTrue);
    expect(state().score, greaterThan(0));
    expect(container.read(highScoreProvider), state().score);
  });

  test('8. the starting shuffle never spells the target word', () {
    for (final word in ['TIGER', 'AB', 'HELLO', 'NOON', 'KANGAROO']) {
      for (var i = 0; i < 200; i++) {
        controller.startRound(word: word, category: 'Test');
        expect(state().tray.map((t) => t.char).join(), isNot(word));
        expect(
          (state().tray.map((t) => t.char).toList()..sort()).join(),
          (word.split('')..sort()).join(),
        );
      }
    }
  });

  group('more rules', () {
    test('10 wrong drops lose the round', () {
      loseLives(10);
      expect(state().livesRemaining, 0);
      expect(state().status, GameStatus.lostLives);
      expect(
        controller.onLetterDropped(tile: tileFor('T'), slotIndex: 0),
        DropResult.ignored,
      );
    });

    test('dropping onto a locked slot is ignored with no life lost', () {
      controller.onLetterDropped(tile: tileFor('T'), slotIndex: 0);
      final result = controller.onLetterDropped(
        tile: tileFor('I'),
        slotIndex: 0,
      );
      expect(result, DropResult.ignored);
      expect(state().livesRemaining, kMaxLives);
    });

    test('tap-to-place uses the first empty slot with the same rules', () {
      expect(
        controller.onLetterTappedFromTray(tileFor('T')),
        DropResult.accepted,
      );
      expect(
        controller.onLetterTappedFromTray(tileFor('R')),
        DropResult.rejected,
      );
      expect(state().slots, ['T', null, null, null, null]);
      expect(state().livesRemaining, kMaxLives - 1);
      expect(state().lastEvent?.slotIndex, 1);
    });

    test('hint that completes the board wins', () {
      controller.startRound(word: 'BEAR', category: 'Test');
      loseLives(2);
      controller.onLetterDropped(tile: tileFor('E'), slotIndex: 1);
      controller.onLetterDropped(tile: tileFor('A'), slotIndex: 2);
      controller.onLetterDropped(tile: tileFor('R'), slotIndex: 3);
      controller.useHint();
      expect(state().status, GameStatus.won);
    });

    test('timer does not tick while paused for the hint sheet', () {
      loseLives(1);
      controller.onLetterDropped(tile: wrongTileFor(0), slotIndex: 0);
      expect(state().status, GameStatus.pausedForHint);
      controller.tickTimer();
      expect(state().secondsRemaining, kRoundSeconds);
    });

    test('retryRound restores lives, timer and an empty board', () {
      controller.onLetterDropped(tile: tileFor('T'), slotIndex: 0);
      loseLives(3);
      controller.tickTimer();
      controller.retryRound();
      expect(state().targetWord, 'TIGER');
      expect(state().livesRemaining, kMaxLives);
      expect(state().secondsRemaining, kRoundSeconds);
      expect(state().slots.every((s) => s == null), isTrue);
      expect(state().hintUnlocked, isFalse);
    });

    test('life letters are lost from the left', () {
      loseLives(3);
      expect(container.read(lifeLettersProvider), [
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
      ]);
    });
  });
}
