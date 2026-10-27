import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/unscramble_controller.dart';

/// Lightbulb FAB. Hidden until the hint unlocks (2 lives lost), pulses once
/// when it appears, and disappears once the free hint is used.
class HintButton extends ConsumerWidget {
  const HintButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(
      unscrambleControllerProvider.select((s) => s.canUseHint),
    );
    if (!visible) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton(
          tooltip: 'Use hint',
          backgroundColor: scheme.tertiaryContainer,
          foregroundColor: scheme.onTertiaryContainer,
          onPressed: ref
              .read(unscrambleControllerProvider.notifier)
              .openHintSheet,
          child: const Icon(Icons.lightbulb_rounded, size: 28),
        )
        .animate()
        .scaleXY(begin: 0.3, end: 1, duration: 450.ms, curve: Curves.elasticOut)
        .then()
        .scaleXY(end: 1.15, duration: 180.ms)
        .then()
        .scaleXY(end: 1 / 1.15, duration: 220.ms);
  }
}

/// Body of the "Need a hint?" bottom sheet.
class HintSheet extends StatelessWidget {
  const HintSheet({
    super.key,
    required this.category,
    required this.clue,
    required this.onReveal,
    required this.onWatchAd,
    required this.onNoThanks,
  });

  final String category;
  final String? clue;
  final VoidCallback onReveal;

  /// Shows a rewarded ad. Returns true only when the reward was earned.
  /// The sheet closes itself on success; a false result stays open.
  final Future<bool> Function() onWatchAd;
  final VoidCallback onNoThanks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.lightbulb_rounded,
              size: 40,
              color: scheme.tertiary,
            ).animate().shake(hz: 3, rotation: 0.1, duration: 500.ms),
            const SizedBox(height: 8),
            Text(
              'Need a hint?',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              "You've lost 2 lives. Take one free letter on us — "
              'it drops straight into the next empty slot. The clock is paused.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (clue != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$category clue: $clue',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onReveal,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Reveal a letter'),
            ),
            const SizedBox(height: 8),
            _WatchAdButton(onWatch: onWatchAd),
            const SizedBox(height: 4),
            TextButton(onPressed: onNoThanks, child: const Text('No thanks')),
          ],
        ),
      ),
    );
  }
}

class _WatchAdButton extends StatefulWidget {
  const _WatchAdButton({required this.onWatch});

  final Future<bool> Function() onWatch;

  @override
  State<_WatchAdButton> createState() => _WatchAdButtonState();
}

class _WatchAdButtonState extends State<_WatchAdButton> {
  bool _busy = false;
  bool _unavailable = false;

  Future<void> _press() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _unavailable = false;
    });
    var earned = false;
    try {
      earned = await widget.onWatch();
    } catch (error) {
      debugPrint('AdMob rewarded show failed: code=exception message=$error');
      earned = false;
    }
    if (!mounted) return;
    if (earned) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = false;
      _unavailable = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _press,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ondemand_video_rounded),
          label: const Text('Watch ad for an extra letter'),
        ),
        if (_unavailable) ...[
          const SizedBox(height: 8),
          Text(
            "Ad isn't available right now. You can keep playing.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
