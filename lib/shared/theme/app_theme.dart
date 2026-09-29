import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Game-specific colours that Material's ColorScheme doesn't cover.
@immutable
class GameColors extends ThemeExtension<GameColors> {
  const GameColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.backgroundTop,
    required this.backgroundBottom,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color backgroundTop;
  final Color backgroundBottom;

  static const light = GameColors(
    success: Color(0xFF2E9D5B),
    onSuccess: Colors.white,
    warning: Color(0xFFE08A00),
    backgroundTop: Color(0xFFF1ECFF),
    backgroundBottom: Color(0xFFFFF4EC),
  );

  static const dark = GameColors(
    success: Color(0xFF5CD68A),
    onSuccess: Color(0xFF00391A),
    warning: Color(0xFFFFB84D),
    backgroundTop: Color(0xFF1B1530),
    backgroundBottom: Color(0xFF221A1E),
  );

  /// Falls back to the light palette when a test pumps a bare [ThemeData].
  static GameColors of(BuildContext context) =>
      Theme.of(context).extension<GameColors>() ?? light;

  @override
  GameColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? backgroundTop,
    Color? backgroundBottom,
  }) => GameColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    warning: warning ?? this.warning,
    backgroundTop: backgroundTop ?? this.backgroundTop,
    backgroundBottom: backgroundBottom ?? this.backgroundBottom,
  );

  @override
  GameColors lerp(GameColors? other, double t) {
    if (other == null) return this;
    return GameColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom: Color.lerp(
        backgroundBottom,
        other.backgroundBottom,
        t,
      )!,
    );
  }
}

abstract final class AppTheme {
  static const _seed = Color(0xFF6A4DF4);

  static ThemeData light() => _build(Brightness.light, GameColors.light);
  static ThemeData dark() => _build(Brightness.dark, GameColors.dark);

  static ThemeData _build(Brightness brightness, GameColors gameColors) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    // Nunito for body copy, chunky Fredoka for tiles and headings.
    final body = GoogleFonts.nunitoTextTheme(base.textTheme);
    TextStyle? display(TextStyle? s) =>
        GoogleFonts.fredoka(textStyle: s, fontWeight: FontWeight.w600);
    final textTheme = body.copyWith(
      displayLarge: display(body.displayLarge),
      displayMedium: display(body.displayMedium),
      displaySmall: display(body.displaySmall),
      headlineLarge: display(body.headlineLarge),
      headlineMedium: display(body.headlineMedium),
      headlineSmall: display(body.headlineSmall),
      titleLarge: display(body.titleLarge),
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: [gameColors],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.fredoka(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    );
  }
}
