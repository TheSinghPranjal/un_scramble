import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_log.dart';
import 'ad_policy.dart';
import 'ad_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  final AdService service = adsPlatformSupported
      ? GoogleMobileAdsService()
      : const NoopAdService();
  ref.onDispose(service.dispose);
  return service;
});

/// Clock for the interstitial cap. Tests override this.
final adClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final interstitialPolicyProvider = Provider<InterstitialPolicy>((ref) {
  return InterstitialPolicy(startedAt: ref.read(adClockProvider)());
});

final interstitialAdManagerProvider = Provider<InterstitialAdManager>(
  InterstitialAdManager.new,
);

/// Shows an interstitial at a natural break when the policy allows it and an
/// ad is already loaded. If it is not loaded, returns immediately so the
/// game continues. The close button is the SDK's; this never blocks dismissal.
class InterstitialAdManager {
  InterstitialAdManager(this._ref);

  final Ref _ref;

  Future<void> onNaturalBreak() async {
    final service = _ref.read(adServiceProvider);
    if (!service.isSupported) return;
    try {
      final policy = _ref.read(interstitialPolicyProvider);
      final now = _ref.read(adClockProvider)();
      if (!policy.registerBreak(now)) return;
      if (!service.isInterstitialReady) {
        debugPrint(
          formatAdFailure(
            'interstitial show',
            code: 'not_ready',
            message: 'ad not loaded; continuing without blocking',
          ),
        );
        unawaited(service.preloadInterstitial());
        return;
      }
      final shown = await service.showInterstitial();
      if (shown) {
        policy.markShown(_ref.read(adClockProvider)());
      }
    } catch (error) {
      debugPrint(
        formatAdFailure('interstitial show', message: error.toString()),
      );
    }
  }
}

final privacyOptionsRequiredProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(adServiceProvider);
  if (!service.isSupported) return false;
  try {
    await service.prepare();
    return await service.isPrivacyOptionsRequired();
  } catch (error) {
    debugPrint(formatAdFailure('privacy options', message: error.toString()));
    return false;
  }
});
