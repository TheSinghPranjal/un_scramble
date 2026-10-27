import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/art_palette.dart';
import 'ad_log.dart';
import 'ad_policy.dart';
import 'ad_providers.dart';

/// Reserved banner under every main screen.
///
/// A failed load disposes only that [BannerAd] instance (the SDK requires it)
/// and retries with [bannerRetryDelay]. The slot itself stays on screen.
/// It collapses only when consent was denied, consent is required and missing,
/// or the release ad config was rejected.
class BannerAdSlot extends ConsumerStatefulWidget {
  const BannerAdSlot({super.key});

  static const slotHeight = 50.0;

  @override
  ConsumerState<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends ConsumerState<BannerAdSlot> {
  BannerAd? _ad;
  Timer? _retry;
  int _failures = 0;
  bool _loading = false;
  bool _blocked = false;
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _supported = ref.read(adServiceProvider).isSupported;
    if (_supported) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted || _loading || _ad != null || _blocked || !_supported) return;
    _loading = true;
    final service = ref.read(adServiceProvider);
    final width = MediaQuery.sizeOf(context).width.truncate();
    try {
      final result = await service.loadBanner(width);
      if (!mounted) {
        result.ad?.dispose();
        return;
      }
      _loading = false;
      if (result.stopRetrying) {
        result.ad?.dispose();
        setState(() => _blocked = true);
        return;
      }
      final ad = result.ad;
      if (ad == null) {
        _scheduleRetry();
        return;
      }
      _failures = 0;
      setState(() => _ad = ad);
    } catch (error) {
      debugPrint(formatAdFailure('banner load', message: error.toString()));
      if (!mounted) return;
      _loading = false;
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _failures += 1;
    final delay = bannerRetryDelay(_failures);
    debugPrint(
      formatAdFailure(
        'banner retry',
        code: 'retry',
        message: 'attempt $_failures in ${delay.inSeconds}s',
      ),
    );
    _retry?.cancel();
    _retry = Timer(delay, () {
      if (mounted) _load();
    });
    setState(() {});
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked) return const SizedBox.shrink();
    final bottom = MediaQuery.paddingOf(context).bottom;
    final ad = _ad;
    final height = ad?.size.height.toDouble() ?? BannerAdSlot.slotHeight;
    return ColoredBox(
      color: ArtPalette.lavender,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: ad == null
              ? const Center(
                  child: Text(
                    'Advertisement',
                    style: TextStyle(color: ArtPalette.muted, fontSize: 12),
                  ),
                )
              : Center(
                  child: SizedBox(
                    width: ad.size.width.toDouble(),
                    height: ad.size.height.toDouble(),
                    child: AdWidget(ad: ad),
                  ),
                ),
        ),
      ),
    );
  }
}
