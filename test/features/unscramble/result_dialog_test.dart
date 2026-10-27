import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:un_scramble/features/unscramble/domain/models.dart';
import 'package:un_scramble/features/unscramble/presentation/widgets/result_dialog.dart';

void main() {
  UnscrambleGameState lost(GameStatus status) {
    return UnscrambleGameState.initial().copyWith(
      targetWord: 'TIGER',
      category: 'Animals',
      status: status,
      livesRemaining: status == GameStatus.lostLives ? 0 : kMaxLives,
      secondsRemaining: 0,
    );
  }

  Future<void> open(
    WidgetTester tester, {
    required GameStatus status,
    required Future<bool> Function() onRewardedContinue,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showResultDialog(
                  context,
                  state: lost(status),
                  onNext: () {},
                  onRetry: () {},
                  onHome: () {},
                  onRewardedContinue: onRewardedContinue,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('extra life stays available when the rewarded ad is not ready', (
    tester,
  ) async {
    await open(
      tester,
      status: GameStatus.lostLives,
      onRewardedContinue: () async => false,
    );
    expect(find.text('Extra life'), findsOneWidget);
    expect(find.text('Coming soon'), findsNothing);

    await tester.tap(find.text('Extra life'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text("Ad isn't available right now. You can keep playing."),
      findsOneWidget,
    );
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('earning the reward closes the dialog', (tester) async {
    var earnedCalls = 0;
    await open(
      tester,
      status: GameStatus.lostTimeout,
      onRewardedContinue: () async {
        earnedCalls++;
        return true;
      },
    );
    expect(find.text('Extra 30 seconds'), findsOneWidget);

    await tester.tap(find.text('Extra 30 seconds'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(earnedCalls, 1);
    expect(find.text('Home'), findsNothing);
  });
}
