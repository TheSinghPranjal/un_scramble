import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/theme/art_palette.dart';
import '../../application/unscramble_controller.dart';
import '../../domain/models.dart';
import 'letter_tile_face.dart';
import 'shake.dart';

/// The hero row of answer slots. Scrolls horizontally when the word is too
/// long to fit at a comfortable size (small phones, 7–8 letter words).
class AnswerSlotsRow extends ConsumerWidget {
  const AnswerSlotsRow({super.key});

  static const double _gap = 6;
  static const double _maxWidth = 56;
  static const double _minWidth = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(
      unscrambleControllerProvider.select((s) => s.slots),
    );
    final playing = ref.watch(
      unscrambleControllerProvider.select(
        (s) => s.status == GameStatus.playing,
      ),
    );
    final lastEvent = ref.watch(
      unscrambleControllerProvider.select((s) => s.lastEvent),
    );
    final controller = ref.read(unscrambleControllerProvider.notifier);
    final n = slots.length;
    if (n == 0) return const SizedBox(height: 64);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitWidth = (constraints.maxWidth - _gap * (n - 1)) / n;
        final scrolls = fitWidth < _minWidth;
        final width = scrolls ? 48.0 : math.min(_maxWidth, fitWidth);
        final height = math.max(56.0, width * 1.15);

        final row = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              AnswerSlot(
                index: i,
                letter: slots[i],
                width: width,
                height: height,
                canAccept: playing,
                event: lastEvent?.slotIndex == i ? lastEvent : null,
                onDrop: (tile) =>
                    controller.onLetterDropped(tile: tile, slotIndex: i),
              ),
            ],
          ],
        );

        if (!scrolls) return Center(child: row);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          clipBehavior: Clip.none,
          child: row,
        );
      },
    );
  }
}

class AnswerSlot extends StatefulWidget {
  const AnswerSlot({
    super.key,
    required this.index,
    required this.letter,
    required this.width,
    required this.height,
    required this.canAccept,
    required this.event,
    required this.onDrop,
  });

  final int index;

  /// Locked correct letter, or null when empty.
  final String? letter;
  final double width;
  final double height;
  final bool canAccept;

  /// Latest game event targeting THIS slot (null if the latest was elsewhere).
  final GameEvent? event;
  final DropResult Function(LetterTile tile) onDrop;

  @override
  State<AnswerSlot> createState() => _AnswerSlotState();
}

class _AnswerSlotState extends State<AnswerSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  Color _flashColor = Colors.transparent;

  @override
  void didUpdateWidget(AnswerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    final event = widget.event;
    if (event != null && event.serial != oldWidget.event?.serial) {
      final colors = GameColors.of(context);
      final wrong = event.type == GameEventType.wrong;
      _flashColor = wrong
          ? Theme.of(context).colorScheme.error
          : colors.success;
      // Green flash is a snappy 150ms; the red one lingers a little longer.
      _flash.duration = Duration(milliseconds: wrong ? 380 : 150);
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.letter;
    final label = letter == null
        ? 'Slot ${widget.index + 1} empty'
        : 'Slot ${widget.index + 1} letter $letter locked';
    final wrongSerial = widget.event?.type == GameEventType.wrong
        ? widget.event!.serial
        : null;

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: ShakeOnTrigger(
        trigger: wrongSerial,
        child: DragTarget<LetterTile>(
          // Accept every letter into an EMPTY slot — the controller then
          // decides right/wrong, so wrong drops reliably cost a life. Locked
          // slots refuse the drop, which bounces the tile back for free.
          onWillAcceptWithDetails: (_) => widget.canAccept && letter == null,
          onAcceptWithDetails: (details) => widget.onDrop(details.data),
          builder: (context, candidates, _) {
            final hovering = candidates.isNotEmpty;
            return AnimatedScale(
              scale: hovering ? 1.05 : 1,
              duration: const Duration(milliseconds: 120),
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: letter == null
                          ? _EmptySlot(hovering: hovering, width: widget.width)
                          : _LockedLetter(
                              letter: letter,
                              width: widget.width,
                              height: widget.height,
                            ),
                    ),
                    Positioned.fill(child: _flashOverlay()),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _flashOverlay() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _flash,
        builder: (context, _) {
          final t = _flash.value;
          if (t == 0 || t == 1) return const SizedBox.shrink();
          return DecoratedBox(
            decoration: BoxDecoration(
              color: _flashColor.withValues(alpha: 0.55 * (1 - t)),
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.hovering, required this.width});

  final bool hovering;
  final double width;

  @override
  Widget build(BuildContext context) {
    final radius = width < 44 ? 12.0 : 16.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: hovering
            ? ArtPalette.lavenderDeep.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(radius),
        border: hovering
            ? Border.all(color: ArtPalette.purple, width: 2.5)
            : null,
        boxShadow: hovering
            ? [
                BoxShadow(
                  color: ArtPalette.purple.withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: hovering
          ? null
          : CustomPaint(
              painter: DashedRRectPainter(
                color: ArtPalette.slotDash,
                radius: radius,
              ),
            ),
    );
  }
}

class _LockedLetter extends StatelessWidget {
  const _LockedLetter({
    required this.letter,
    required this.width,
    required this.height,
  });

  final String letter;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Spring "snap" into place.
        LetterTileFace(
          char: letter,
          width: width,
          height: height,
          tone: TileTone.locked,
        ).animate().scaleXY(
          begin: 0.7,
          end: 1,
          duration: 420.ms,
          curve: Curves.elasticOut,
        ),
        // Check micro-animation: pops in, then fades away.
        Positioned(
          top: -6,
          right: -6,
          child:
              Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.success,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: colors.onSuccess,
                    ),
                  )
                  .animate()
                  .scaleXY(
                    begin: 0,
                    end: 1,
                    duration: 300.ms,
                    curve: Curves.elasticOut,
                  )
                  .then(delay: 450.ms)
                  .fadeOut(duration: 250.ms),
        ),
      ],
    );
  }
}

class DashedRRectPainter extends CustomPainter {
  DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      Radius.circular(radius),
    );
    const dash = 6.0;
    const space = 4.0;
    final path = Path()..addRRect(rrect);
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + space;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
