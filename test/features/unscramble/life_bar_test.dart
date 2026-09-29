import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:un_scramble/features/unscramble/presentation/widgets/unscramble_life_bar.dart';

void main() {
  testWidgets('life bar strikes lost letters from the left', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: LifeBarView(
              alive: [
                false,
                false,
                true,
                true,
                true,
                true,
                true,
                true,
                true,
                true,
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    TextDecoration? decorationOf(String letter) =>
        tester.widget<Text>(find.text(letter)).style?.decoration;

    expect(decorationOf('U'), TextDecoration.lineThrough);
    expect(decorationOf('N'), TextDecoration.lineThrough);
    expect(decorationOf('S'), TextDecoration.none);
    expect(decorationOf('E'), TextDecoration.none);
    expect(find.bySemanticsLabel('8 of 10 lives left'), findsOneWidget);
  });
}
