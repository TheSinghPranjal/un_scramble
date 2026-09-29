import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CoachStep {
  const CoachStep({
    required this.target,
    required this.title,
    required this.body,
  });

  final GlobalKey target;
  final String title;
  final String body;
}

/// First-run spotlight: dims the screen, cuts a hole around each target in
/// turn and shows a short caption. Tap anywhere to advance.
class CoachMarksOverlay extends StatefulWidget {
  const CoachMarksOverlay({
    super.key,
    required this.steps,
    required this.onDone,
  });

  final List<CoachStep> steps;
  final VoidCallback onDone;

  @override
  State<CoachMarksOverlay> createState() => _CoachMarksOverlayState();
}

class _CoachMarksOverlayState extends State<CoachMarksOverlay> {
  int _index = 0;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    _measureAfterLayout();
  }

  void _measureAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final self = context.findRenderObject() as RenderBox?;
      final target =
          widget.steps[_index].target.currentContext?.findRenderObject()
              as RenderBox?;
      if (self == null || target == null || !target.hasSize) return;
      final topLeft = self.globalToLocal(target.localToGlobal(Offset.zero));
      setState(() => _hole = (topLeft & target.size).inflate(10));
    });
  }

  void _advance() {
    if (_index >= widget.steps.length - 1) {
      widget.onDone();
      return;
    }
    setState(() {
      _index++;
      _hole = null;
    });
    _measureAfterLayout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = widget.steps[_index];
    final hole = _hole;
    final size = MediaQuery.sizeOf(context);
    // Put the caption on whichever side of the spotlight has more room.
    final captionBelow = hole == null || hole.center.dy < size.height / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _advance,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ScrimPainter(
                hole: hole,
                color: Colors.black.withValues(alpha: 0.68),
              ),
            ),
          ),
          if (hole != null)
            Positioned(
              left: 24,
              right: 24,
              top: captionBelow ? hole.bottom + 16 : null,
              bottom: captionBelow ? null : size.height - hole.top + 16,
              child: Column(
                key: ValueKey(_index),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _index == widget.steps.length - 1
                        ? 'Tap to play'
                        : 'Tap to continue',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.15),
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: TextButton(
              onPressed: widget.onDone,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Skip'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.hole, required this.color});

  final Rect? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = this.hole;
    final path = hole == null
        ? full
        : Path.combine(
            PathOperation.difference,
            full,
            Path()..addRRect(
              RRect.fromRectAndRadius(hole, const Radius.circular(20)),
            ),
          );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.color != color;
}
