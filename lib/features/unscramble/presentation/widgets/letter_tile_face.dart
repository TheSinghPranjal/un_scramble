import 'package:flutter/material.dart';

import '../../../../shared/theme/art_palette.dart';

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
    final radius = BorderRadius.circular(width < 44 ? 12 : 18);
    final lipDepth = width < 44 ? 3.0 : 5.0;

    final (Color face, Color faceTop, Color lip, Color text) = switch (tone) {
      TileTone.tray => (
        ArtPalette.lavender,
        Colors.white,
        ArtPalette.tileLip,
        ArtPalette.ink,
      ),
      TileTone.locked => (
        ArtPalette.purple,
        ArtPalette.purpleLight,
        ArtPalette.purpleDeep,
        Colors.white,
      ),
      TileTone.ghost => (
        ArtPalette.lavenderDeep.withValues(alpha: 0.45),
        ArtPalette.lavenderDeep.withValues(alpha: 0.45),
        Colors.transparent,
        Colors.transparent,
      ),
    };

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Lighter top edge gives the glossy "candy" tile look.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [faceTop, face],
          ),
          borderRadius: radius,
          boxShadow: [
            // Solid "lip" under the tile gives the chunky, pressable look.
            if (tone != TileTone.ghost)
              BoxShadow(color: lip, offset: Offset(0, lipDepth)),
            if (tone == TileTone.tray)
              BoxShadow(
                color: ArtPalette.purple.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: Offset(0, lipDepth + 4),
              ),
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
}
