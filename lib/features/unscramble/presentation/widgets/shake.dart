import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Plays a decaying horizontal shake every time [trigger] changes to a new
/// non-null value. Driven by the `serial` of game events so repeated wrong
/// drops on the same slot each shake again.
class ShakeOnTrigger extends StatefulWidget {
  const ShakeOnTrigger({
    super.key,
    required this.trigger,
    required this.child,
    this.distance = 8,
    this.duration = const Duration(milliseconds: 420),
  });

  final Object? trigger;
  final Widget child;
  final double distance;
  final Duration duration;

  @override
  State<ShakeOnTrigger> createState() => _ShakeOnTriggerState();
}

class _ShakeOnTriggerState extends State<ShakeOnTrigger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(ShakeOnTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != null && widget.trigger != oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final dx = math.sin(t * math.pi * 6) * widget.distance * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
