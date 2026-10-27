import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_log.dart';
import 'ad_providers.dart';

/// Shown only when UMP says the privacy-options entry point is required.
class PrivacyOptionsButton extends ConsumerWidget {
  const PrivacyOptionsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final required = ref.watch(privacyOptionsRequiredProvider);
    return required.when(
      data: (show) {
        if (!show) return const SizedBox.shrink();
        return TextButton(
          onPressed: () => ref.read(adServiceProvider).showPrivacyOptions(),
          child: const Text('Ad privacy settings'),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, _) {
        debugPrint(
          formatAdFailure('privacy options', message: error.toString()),
        );
        return const SizedBox.shrink();
      },
    );
  }
}
