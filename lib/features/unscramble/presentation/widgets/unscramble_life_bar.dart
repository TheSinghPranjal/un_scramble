import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/theme/art_palette.dart';

import '../../application/unscramble_controller.dart';
import '../../domain/models.dart';

/// The brand life bar: U N S C R A M B L E, one letter per life.
class UnscrambleLifeBar extends ConsumerWidget {
  const UnscrambleLifeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LifeBarView(alive: ref.watch(lifeLettersProvider));
  }
}

/// Stateless view of the life bar so it can be tested without a game.
/// `alive[i]` is false for lost lives (always a prefix — lost left to right).
class LifeBarView extends StatelessWidget {
  const LifeBarView({super.key, required this.alive})
    : assert(alive.length == kMaxLives);

  final List<bool> alive;

  @override
  Widget build(BuildContext context) {
    final remaining = alive.where((a) => a).length;
    return Semantics(
      label: '$remaining of $kMaxLives lives left',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 4.0;
          final size = math.min(
            38.0,
            ((constraints.maxWidth - gap * (kMaxLives - 1)) / kMaxLives)
                .floorToDouble(),
          );
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < kMaxLives; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                LifeChip(letter: lifeLetters[i], alive: alive[i], size: size),
              ],
            ],
          );
        },
      ),
    );
  }
}

class LifeChip extends StatefulWidget {
  const LifeChip({
    super.key,
    required this.letter,
    required this.alive,
    required this.size,
  });

  final String letter;
  final bool alive;
  final double size;

  @override
  State<LifeChip> createState() => _LifeChipState();
}

class _LifeChipState extends State<LifeChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lose = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  @override
  void didUpdateWidget(LifeChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the chip that just died plays the shake + drop.
    if (oldWidget.alive && !widget.alive) _lose.forward(from: 0);
  }

  @override
  void dispose() {
    _lose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alive = widget.alive;
    final textStyle = GoogleFonts.fredoka(
      fontSize: widget.size * 0.55,
      height: 1,
      fontWeight: alive ? FontWeight.w700 : FontWeight.w500,
      color: alive ? Colors.white : ArtPalette.muted,
      decoration: alive ? TextDecoration.none : TextDecoration.lineThrough,
      decorationColor: ArtPalette.heart,
      decorationThickness: 2.5,
    );

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: widget.size,
      height: widget.size * 1.15,
      decoration: BoxDecoration(
        // Lighter top edge matches the glossy letter tiles.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: alive
              ? const [ArtPalette.purpleLight, ArtPalette.purple]
              : const [ArtPalette.lavender, ArtPalette.lavenderDeep],
        ),
        borderRadius: BorderRadius.circular(widget.size * 0.3),
        boxShadow: alive
            ? [
                const BoxShadow(
                  color: ArtPalette.purpleDeep,
                  offset: Offset(0, 3),
                ),
                BoxShadow(
                  color: ArtPalette.purple.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(widget.letter, style: textStyle),
    );

    return AnimatedBuilder(
      animation: _lose,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: alive ? 1 : 0.6,
        child: chip,
      ),
      builder: (context, child) {
        final t = _lose.value;
        if (t == 0 || t == 1) return child!;
        final dx = math.sin(t * math.pi * 5) * 5 * (1 - t);
        final scale = 1 + 0.25 * math.sin(t * math.pi) * (1 - t);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}
