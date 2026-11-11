import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:un_scramble/features/unscramble/presentation/home_screen.dart';
import 'package:un_scramble/features/unscramble/presentation/splash_screen.dart';
import 'package:un_scramble/shared/theme/app_theme.dart';
import 'package:un_scramble/shared/theme/art_palette.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpSplash(
    WidgetTester tester, {
    ThemeData? theme,
    Size size = const Size(390, 844),
    double textScale = 1,
    Duration duration = const Duration(minutes: 5),
    Widget next = const SizedBox.shrink(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme:
            theme ??
            ThemeData(useMaterial3: true, extensions: const [GameColors.light]),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: SplashScreen(duration: duration, next: next),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the app name and The Lazy Bear Club byline', (
    tester,
  ) async {
    await pumpSplash(tester);

    expect(find.text('Unscramble'), findsOneWidget);
    expect(find.text('by'), findsOneWidget);
    expect(find.text('The Lazy Bear Club'), findsOneWidget);
    expect(find.bySemanticsLabel('by The Lazy Bear Club'), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, lazyBearClubIconAsset);

    final title = tester.widget<Text>(find.text('Unscramble'));
    expect(title.style?.color, ArtPalette.purpleDeep);
    final studio = tester.widget<Text>(find.text('The Lazy Bear Club'));
    expect(studio.style?.color, ArtPalette.ink);

    final titleY = tester.getTopLeft(find.text('Unscramble')).dy;
    final iconY = tester.getTopLeft(find.byType(Image)).dy;
    final byY = tester.getTopLeft(find.text('by')).dy;
    final studioY = tester.getTopLeft(find.text('The Lazy Bear Club')).dy;
    expect(iconY, greaterThan(titleY));
    expect(byY, greaterThan(iconY));
    expect(studioY, greaterThan(byY));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the byline readable on a dark theme', (tester) async {
    await pumpSplash(
      tester,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        extensions: const [GameColors.dark],
      ),
    );

    final title = tester.widget<Text>(find.text('Unscramble'));
    final byline = tester.widget<Text>(find.text('by'));
    final studio = tester.widget<Text>(find.text('The Lazy Bear Club'));
    expect(
      _contrast(title.style!.color!, GameColors.dark.backgroundTop) > 4.5,
      isTrue,
    );
    expect(
      _contrast(byline.style!.color!, GameColors.dark.backgroundBottom) > 4.5,
      isTrue,
    );
    expect(
      _contrast(studio.style!.color!, GameColors.dark.backgroundBottom) > 4.5,
      isTrue,
    );
    expect(_isLight(title.style!.color!), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out on a small phone, a tablet, and large text', (
    tester,
  ) async {
    const cases = <(Size, double)>[
      (Size(320, 480), 1),
      (Size(320, 568), 2),
      (Size(360, 640), 1.4),
      (Size(768, 1024), 1),
      (Size(1024, 1366), 1.3),
    ];

    for (final (size, scale) in cases) {
      await pumpSplash(tester, size: size, textScale: scale);
      expect(tester.takeException(), isNull, reason: '$size @ $scale');
      expect(find.text('Unscramble'), findsOneWidget);
      expect(find.text('The Lazy Bear Club'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('opens the next screen after the splash duration', (
    tester,
  ) async {
    const hold = Duration(milliseconds: 1900);
    await pumpSplash(
      tester,
      duration: hold,
      next: const Scaffold(body: Text('home-ready')),
    );

    expect(find.text('Unscramble'), findsOneWidget);
    expect(find.text('home-ready'), findsNothing);

    await tester.pump(hold);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('home-ready'), findsOneWidget);
    expect(find.text('Unscramble'), findsNothing);
    expect(find.text('The Lazy Bear Club'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('defaults to the home screen', () {
    const splash = SplashScreen();
    expect(splash.next, isA<HomeScreen>());
    expect(splash.duration, splashDuration);
  });

  testWidgets('uses the app theme colours without throwing', (tester) async {
    await pumpSplash(tester, theme: AppTheme.light());
    expect(find.text('Unscramble'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpSplash(
      tester,
      theme: AppTheme.dark(),
      size: const Size(320, 568),
      textScale: 1.6,
    );
    final studio = tester.widget<Text>(find.text('The Lazy Bear Club'));
    expect(_isLight(studio.style!.color!), isTrue);
    expect(tester.takeException(), isNull);
  });
}

bool _isLight(Color color) => color.computeLuminance() > 0.7;

/// WCAG contrast ratio between [foreground] and [background].
double _contrast(Color foreground, Color background) {
  final lighter = mathMax(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = mathMin(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + 0.05) / (darker + 0.05);
}

double mathMax(double a, double b) => a > b ? a : b;

double mathMin(double a, double b) => a < b ? a : b;
