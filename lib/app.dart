import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/unscramble/presentation/home_screen.dart';
import 'shared/ads/ad_providers.dart';
import 'shared/ads/banner_ad_slot.dart';
import 'shared/theme/app_theme.dart';

class UnscrambleApp extends ConsumerStatefulWidget {
  const UnscrambleApp({super.key});

  @override
  ConsumerState<UnscrambleApp> createState() => _UnscrambleAppState();
}

class _UnscrambleAppState extends ConsumerState<UnscrambleApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Starts the 90s interstitial clock and the consent/SDK init. Init is
      // retried by the banner if it throws; a failed UMP check does not
      // disable ads inside prepare().
      ref.read(interstitialPolicyProvider);
      unawaited(ref.read(adServiceProvider).prepare());
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unscramble',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return Column(
          children: [
            Expanded(
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(bottom: 0),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            const BannerAdSlot(),
          ],
        );
      },
      home: const HomeScreen(),
    );
  }
}
