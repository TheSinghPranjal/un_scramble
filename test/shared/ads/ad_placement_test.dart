import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:un_scramble/shared/ads/ad_policy.dart';
import 'package:un_scramble/shared/ads/ad_providers.dart';
import 'package:un_scramble/shared/ads/ad_service.dart';
import 'package:un_scramble/shared/ads/banner_ad_slot.dart';

class _ReadyAds extends NoopAdService {
  _ReadyAds({this.ready = false, this.showResult = true});

  bool ready;
  final bool showResult;
  int shows = 0;
  int preloads = 0;

  @override
  bool get isSupported => true;

  @override
  bool get isInterstitialReady => ready;

  @override
  Future<void> preloadInterstitial() async {
    preloads++;
  }

  @override
  Future<bool> showInterstitial() async {
    shows++;
    return showResult;
  }
}

class _BannerAds extends NoopAdService {
  _BannerAds({required this.stop});

  final bool stop;

  @override
  bool get isSupported => true;

  @override
  Future<BannerLoadResult> loadBanner(int width) async {
    return BannerLoadResult(stopRetrying: stop);
  }
}

void main() {
  test(
    'a break with no ad loaded does not block or consume the show',
    () async {
      final ads = _ReadyAds();
      var now = DateTime(2026, 1, 1, 12);
      final container = ProviderContainer(
        overrides: [
          adServiceProvider.overrideWithValue(ads),
          adClockProvider.overrideWith(
            (ref) =>
                () => now,
          ),
        ],
      );
      addTearDown(container.dispose);
      final manager = container.read(interstitialAdManagerProvider);

      await manager.onNaturalBreak();
      now = now.add(const Duration(seconds: 90));
      await manager.onNaturalBreak();

      expect(ads.shows, 0);
      expect(ads.preloads, 1);

      ads.ready = true;
      await manager.onNaturalBreak();
      expect(ads.shows, 1);

      await manager.onNaturalBreak();
      expect(ads.shows, 1);
    },
  );

  test('a failed show does not start the 90 second cap', () async {
    final ads = _ReadyAds(ready: true, showResult: false);
    var now = DateTime(2026, 1, 1, 12);
    final container = ProviderContainer(
      overrides: [
        adServiceProvider.overrideWithValue(ads),
        adClockProvider.overrideWith(
          (ref) =>
              () => now,
        ),
      ],
    );
    addTearDown(container.dispose);
    final manager = container.read(interstitialAdManagerProvider);

    await manager.onNaturalBreak();
    now = now.add(InterstitialPolicy.minInterval);
    await manager.onNaturalBreak();
    expect(ads.shows, 1);

    // The failed presentation did not start the cap, so the next break retries
    // without waiting another 90 seconds.
    await manager.onNaturalBreak();
    expect(ads.shows, 2);
  });

  testWidgets('the banner slot stays visible when ads are unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adServiceProvider.overrideWithValue(const NoopAdService())],
        child: const MaterialApp(home: Scaffold(body: BannerAdSlot())),
      ),
    );
    expect(find.text('Advertisement'), findsOneWidget);
  });

  testWidgets('the banner slot stops only when consent blocks requests', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adServiceProvider.overrideWithValue(_BannerAds(stop: true)),
        ],
        child: const MaterialApp(home: Scaffold(body: BannerAdSlot())),
      ),
    );
    await tester.pump();
    expect(find.text('Advertisement'), findsNothing);
  });
}
