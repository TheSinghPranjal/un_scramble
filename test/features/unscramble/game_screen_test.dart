import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:un_scramble/features/unscramble/application/unscramble_controller.dart';
import 'package:un_scramble/features/unscramble/domain/models.dart';
import 'package:un_scramble/features/unscramble/presentation/game_screen.dart';
import 'package:un_scramble/features/unscramble/presentation/widgets/answer_slots_row.dart';
import 'package:un_scramble/shared/prefs/preferences.dart';

void main() {
  late ProviderContainer container;

  UnscrambleGameState state() => container.read(unscrambleControllerProvider);

  Future<void> pumpGame(WidgetTester tester, String word) async {
    // Small phone: 360 x 690 dp.
    tester.view.physicalSize = const Size(1080, 2070);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'coach_marks_seen': true});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        autoTickProvider.overrideWithValue(false),
        randomProvider.overrideWithValue(Random(7)),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(unscrambleControllerProvider.notifier)
        .startRound(word: word, category: 'Test');

    // Plain theme: google_fonts would try to hit the network in tests.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const GameScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> dragTileToSlot(
    WidgetTester tester,
    LetterTile tile,
    int slot,
  ) async {
    final from = tester.getCenter(find.byKey(ValueKey(tile.id)));
    final to = tester.getCenter(find.byType(AnswerSlot).at(slot));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();
  }

  testWidgets('wrong drag costs a life and bounces back; correct drag locks', (
    tester,
  ) async {
    await pumpGame(tester, 'TIGER');
    expect(tester.takeException(), isNull);

    final wrong = state().tray.firstWhere((t) => t.char != 'T');
    await dragTileToSlot(tester, wrong, 0);
    expect(state().livesRemaining, 9);
    expect(state().slots[0], isNull);
    expect(state().tray, contains(wrong));
    await tester.pump(const Duration(milliseconds: 600)); // fly-back finishes

    final right = state().tray.firstWhere((t) => t.char == 'T');
    await dragTileToSlot(tester, right, 0);
    expect(state().slots[0], 'T');
    expect(state().livesRemaining, 9);
    await tester.pump(const Duration(milliseconds: 1500));

    // Dropping onto the locked slot is refused for free.
    await dragTileToSlot(tester, state().tray.first, 0);
    expect(state().livesRemaining, 9);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('second mistake opens the hint sheet; reveal uses the hint', (
    tester,
  ) async {
    await pumpGame(tester, 'TIGER');
    for (var i = 0; i < 2; i++) {
      final wrong = state().tray.firstWhere((t) => t.char != 'T');
      await tester.tap(find.byKey(ValueKey(wrong.id)));
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(state().status, GameStatus.pausedForHint);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Need a hint?'), findsOneWidget);

    await tester.tap(find.text('Reveal a letter'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(state().slots[0], 'T');
    expect(state().hintUsed, isTrue);
    expect(state().status, GameStatus.playing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('8-letter word fits a 360dp screen without overflow', (
    tester,
  ) async {
    await pumpGame(tester, 'KANGAROO');
    expect(tester.takeException(), isNull);
    expect(find.byType(AnswerSlot), findsNWidgets(8));
  });

  testWidgets('winning shows the result dialog with the word', (tester) async {
    await pumpGame(tester, 'BEAR');
    for (final char in 'BEAR'.split('')) {
      await tester.tap(
        find.byKey(ValueKey(state().tray.firstWhere((t) => t.char == char).id)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(state().status, GameStatus.won);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Brilliant!'), findsOneWidget);
    expect(find.text('Next word'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
