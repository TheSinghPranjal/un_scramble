import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/unscramble_controller.dart';
import '../../domain/models.dart';
import 'letter_tile_face.dart';
import 'shake.dart';

const double _tileSize = 56;

/// Scrambled letters the player drags (or taps) into the answer slots.
class LetterTray extends ConsumerWidget {
  const LetterTray({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tray = ref.watch(unscrambleControllerProvider.select((s) => s.tray));
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 14,
      children: [
        for (final tile in tray) TrayTile(key: ValueKey(tile.id), tile: tile),
      ],
    );
  }
}

class TrayTile extends ConsumerStatefulWidget {
  const TrayTile({super.key, required this.tile});

  final LetterTile tile;

  @override
  ConsumerState<TrayTile> createState() => _TrayTileState();
}

class _TrayTileState extends ConsumerState<TrayTile> {
  /// Anchor on the outer box: it stays mounted while the Draggable swaps
  /// its child for the placeholder, so we can always find our home spot.
  final GlobalKey _homeKey = GlobalKey();
  bool _flyingHome = false;

  @override
  Widget build(BuildContext context) {
    final tile = widget.tile;
    final playing = ref.watch(
      unscrambleControllerProvider.select(
        (s) => s.status == GameStatus.playing,
      ),
    );
    // Shake when this tile was the one rejected by a tap-to-place.
    final wrongSerial = ref.watch(
      unscrambleControllerProvider.select((s) {
        final e = s.lastEvent;
        return e != null && e.type == GameEventType.wrong && e.tileId == tile.id
            ? e.serial
            : null;
      }),
    );

    const ghost = LetterTileFace(char: '', tone: TileTone.ghost);
    final face = LetterTileFace(char: tile.char);

    return Semantics(
      label: 'Letter ${tile.char}',
      hint: 'Drag to a slot, or tap to place in the next empty slot',
      button: true,
      child: SizedBox(
        key: _homeKey,
        width: _tileSize,
        height: _tileSize,
        child: _flyingHome
            ? ghost
            : ShakeOnTrigger(
                trigger: wrongSerial,
                child: Draggable<LetterTile>(
                  data: tile,
                  maxSimultaneousDrags: playing ? 1 : 0,
                  onDragStarted: HapticFeedback.lightImpact,
                  onDragEnd: (details) => _flyHomeIfStillInTray(details.offset),
                  feedback: Material(
                    type: MaterialType.transparency,
                    child: LetterTileFace(
                      char: tile.char,
                      lifted: true,
                    ).animate().scaleXY(begin: 1, end: 1.12, duration: 120.ms),
                  ),
                  childWhenDragging: ghost,
                  child: GestureDetector(
                    onTap: playing ? _tapToPlace : null,
                    child: face,
                  ),
                ),
              ),
      ),
    );
  }

  void _tapToPlace() {
    ref
        .read(unscrambleControllerProvider.notifier)
        .onLetterTappedFromTray(widget.tile);
  }

  /// Runs after any drag ends — including after a slot's onAccept. If the
  /// controller did not consume the tile (wrong letter, locked slot, dropped
  /// on nothing) animate it flying back from where it was released.
  void _flyHomeIfStillInTray(Offset releasedAt) {
    if (!mounted) return;
    final stillInTray = ref
        .read(unscrambleControllerProvider)
        .tray
        .contains(widget.tile);
    if (!stillInTray) return;

    final home = _homeKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (home == null ||
        !home.attached ||
        overlay == null ||
        overlayBox == null) {
      return;
    }
    final from = overlayBox.globalToLocal(releasedAt);
    final to = overlayBox.globalToLocal(home.localToGlobal(Offset.zero));
    if ((to - from).distance < 4) return;

    setState(() => _flyingHome = true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FlyingTile(
        char: widget.tile.char,
        from: from,
        to: to,
        onDone: () {
          entry.remove();
          if (mounted) setState(() => _flyingHome = false);
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _FlyingTile extends StatefulWidget {
  const _FlyingTile({
    required this.char,
    required this.from,
    required this.to,
    required this.onDone,
  });

  final String char;
  final Offset from;
  final Offset to;
  final VoidCallback onDone;

  @override
  State<_FlyingTile> createState() => _FlyingTileState();
}

class _FlyingTileState extends State<_FlyingTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward().whenComplete(widget.onDone);

  late final Animation<Offset> _position = Tween(
    begin: widget.from,
    end: widget.to,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Positioned(
        left: _position.value.dx,
        top: _position.value.dy,
        child: Transform.rotate(
          angle:
              0.25 *
              (1 - _controller.value) *
              (widget.to.dx < widget.from.dx ? -1 : 1),
          child: child,
        ),
      ),
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: LetterTileFace(char: widget.char, lifted: true),
        ),
      ),
    );
  }
}
