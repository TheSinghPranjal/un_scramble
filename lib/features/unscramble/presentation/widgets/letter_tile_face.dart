import 'package:flutter/material.dart';

enum TileTone {
  /// Loose letter in the tray.
  tray,

  /// Correct letter locked into a slot.
  locked,

  /// Faded placeholder left behind while a tile is being dragged.
  ghost,
}

/// Chunky rounded letter tile. Purely visual — drag/tap behaviour lives in
/// the tray and slot widgets.
class LetterTileFace extends StatelessWidget {
  const LetterTileFace({
    super.key,
    required this.char,
    this.width = 56,
    this.height = 56,
    this.tone = TileTone.tray,
    this.lifted = false,
  });

  final String char;
  final double width;
  final double height;
  final TileTone tone;

  /// Adds the soft drop shadow used while a tile is being dragged.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(width < 44 ? 12 : 16);
    final lipDepth = width < 44 ? 3.0 : 4.0;

    final (Color face, Color lip, Color text) = switch (tone) {
      TileTone.tray => (
        scheme.surfaceContainerLowest,
        scheme.outlineVariant,
        scheme.onSurface,
      ),
      TileTone.locked => (
        scheme.primary,
        _darken(scheme.primary),
        scheme.onPrimary,
      ),
      TileTone.ghost => (
        scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        Colors.transparent,
        Colors.transparent,
      ),
    };

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: face,
          borderRadius: radius,
          boxShadow: [
            // Solid "lip" under the tile gives the chunky, pressable look.
            if (tone != TileTone.ghost)
              BoxShadow(color: lip, offset: Offset(0, lipDepth)),
            if (lifted)
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Center(
          child: Text(
            char,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: text,
              fontWeight: FontWeight.w700,
              fontSize: height * 0.5,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  static Color _darken(Color c) => Color.lerp(c, Colors.black, 0.28) ?? c;
}
