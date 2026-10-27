import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ad_log.dart';
import 'admob_config.dart';
import 'consent_decision.dart';

/// Whether this process can show ads. Widget tests and desktop builds are not
/// Android or iOS, so they never touch the plugin.
bool get adsPlatformSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

AdPlatform currentAdPlatform() =>
    !kIsWeb && Platform.isIOS ? AdPlatform.ios : AdPlatform.android;

class AdsRequestGate {
  const AdsRequestGate({
    required this.decision,
    required this.sdkReady,
    this.configRejected = false,
  });

  final AdsConsentDecision decision;
  final bool sdkReady;
  final bool configRejected;

  bool get mayRequestAds =>
      shouldAttemptSdkInitialization(decision) && !configRejected;
}

class BannerLoadResult {
  const BannerLoadResult({this.ad, required this.stopRetrying});

  final BannerAd? ad;

  /// True only when another attempt would violate consent or a rejected
  /// release config. Load failures and init exceptions keep this false so the
  /// banner slot stays up and retries.
  final bool stopRetrying;
}

abstract interface class ConsentClient {
  Future<ConsentSnapshot> gather();
  Future<bool> isPrivacyOptionsRequired();
  Future<void> showPrivacyOptions();
}

abstract interface class AdService {
  bool get isSupported;
  Future<AdsRequestGate> prepare();
  Future<BannerLoadResult> loadBanner(int width);
  bool get isInterstitialReady;
  Future<void> preloadInterstitial();
  Future<bool> showInterstitial();
  Future<bool> showRewarded();
  Future<bool> isPrivacyOptionsRequired();
  Future<void> showPrivacyOptions();
  void dispose();
}

class NoopAdService implements AdService {
  const NoopAdService();

  @override
  bool get isSupported => false;

  @override
  Future<AdsRequestGate> prepare() async => const AdsRequestGate(
    decision: AdsConsentDecision.requestAds,
    sdkReady: false,
  );

  @override
  Future<BannerLoadResult> loadBanner(int width) async =>
      const BannerLoadResult(stopRetrying: true);

  @override
  bool get isInterstitialReady => false;

  @override
  Future<void> preloadInterstitial() async {}

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<bool> showRewarded() async => false;

  @override
  Future<bool> isPrivacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  void dispose() {}
}

typedef ConfigLoader = Future<AdmobConfig?> Function();
typedef SdkInitializer = Future<void> Function();

class GoogleMobileAdsService implements AdService {
  GoogleMobileAdsService({
    ConsentClient? consentClient,
    ConfigLoader? loadConfig,
    SdkInitializer? initializeSdk,
    bool? supported,
    bool? releaseMode,
    AdPlatform? platform,
    void Function(String message)? log,
    bool preloadAfterInit = true,
  }) : _consent = consentClient ?? SdkConsentClient(log: log ?? debugPrint),
       _loadConfig = loadConfig ?? _loadBundledConfig,
       _initializeSdk = initializeSdk ?? _defaultInitialize,
       _supported = supported ?? adsPlatformSupported,
       _releaseMode = releaseMode ?? kReleaseMode,
       _platform = platform ?? currentAdPlatform(),
       _log = log ?? debugPrint,
       _preloadAfterInit = preloadAfterInit;

  final ConsentClient _consent;
  final ConfigLoader _loadConfig;
  final SdkInitializer _initializeSdk;
  final bool _supported;
  final bool _releaseMode;
  final AdPlatform _platform;
  final void Function(String message) _log;
  final bool _preloadAfterInit;

  AdmobConfig? _config;
  bool _configRejected = false;
  Future<AdsConsentDecision>? _consentDecision;
  bool _sdkReady = false;
  Future<bool>? _initInFlight;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  Future<bool>? _interstitialLoad;
  Future<bool>? _rewardedLoad;
  bool _disposed = false;

  static Future<AdmobConfig?> _loadBundledConfig() async {
    try {
      return await loadAdmobConfig(rootBundle);
    } catch (error) {
      debugPrint(formatAdFailure('config load', message: error.toString()));
      if (kReleaseMode) rethrow;
      return null;
    }
  }

  static Future<void> _defaultInitialize() {
    return MobileAds.instance.initialize();
  }

  @override
  bool get isSupported => _supported;

  @visibleForTesting
  AdUnitIds get unitIds =>
      (_config ??
              const AdmobConfig(
                androidAppId: '',
                androidBannerId: '',
                androidInterstitialId: '',
                androidRewardedId: '',
                iosAppId: '',
                iosBannerId: '',
                iosInterstitialId: '',
                iosRewardedId: '',
              ))
          .unitIds(releaseMode: _releaseMode, platform: _platform);

  @override
  Future<AdsRequestGate> prepare() async {
    if (!_supported) {
      return const AdsRequestGate(
        decision: AdsConsentDecision.requestAds,
        sdkReady: false,
      );
    }
    if (_configRejected) {
      return AdsRequestGate(
        decision: AdsConsentDecision.requestAds,
        sdkReady: false,
        configRejected: true,
      );
    }

    try {
      _config ??= await _loadConfig();
      if (_releaseMode) {
        final config = _config;
        if (config == null) {
          throw const InvalidReleaseAdIdException('config/admob.json', '');
        }
        config.validateForRelease(_platform);
      }
    } catch (error) {
      // Debug/profile keep going on a missing asset and use test ids.
      // Release must not request ads with a test, placeholder, or unreadable
      // config — and must not retry that forever.
      if (!_releaseMode && error is! InvalidReleaseAdIdException) {
        _log(formatAdFailure('config load', message: error.toString()));
      } else {
        _configRejected = true;
        _log(
          formatAdFailure(
            'release config',
            code: 'invalid_id',
            message: error.toString(),
          ),
        );
        return const AdsRequestGate(
          decision: AdsConsentDecision.requestAds,
          sdkReady: false,
          configRejected: true,
        );
      }
    }

    final decision = await (_consentDecision ??= _resolveConsent());
    if (!shouldAttemptSdkInitialization(decision)) {
      _log(
        'AdMob init skipped: code=$decision '
        'message=consent does not allow ad requests',
      );
      return AdsRequestGate(decision: decision, sdkReady: false);
    }

    final ready = await _tryInitialize();
    if (ready && _preloadAfterInit) _preloadFullScreen();
    return AdsRequestGate(decision: decision, sdkReady: ready);
  }

  Future<AdsConsentDecision> _resolveConsent() async {
    try {
      final snapshot = await _consent.gather();
      final decision = decideConsent(snapshot);
      _log(
        'AdMob consent decision: $decision '
        '(updateCompleted=${snapshot.updateCompleted}, '
        'status=${snapshot.status.name}, '
        'canRequestAds=${snapshot.canRequestAds})',
      );
      return decision;
    } catch (error) {
      // A thrown UMP check is not a denial. Keep requesting ads.
      _log(formatAdFailure('consent check', message: error.toString()));
      return AdsConsentDecision.requestAds;
    }
  }

  Future<bool> _tryInitialize() {
    if (_sdkReady) return Future<bool>.value(true);
    return _initInFlight ??= _initialize().whenComplete(() {
      _initInFlight = null;
    });
  }

  Future<bool> _initialize() async {
    try {
      await _initializeSdk();
      _sdkReady = true;
      _log('AdMob init succeeded');
      return true;
    } catch (error) {
      // Do not latch ads off. The next prepare() tries initialize again.
      _sdkReady = false;
      _logFailure('init', error);
      return false;
    }
  }

  void _preloadFullScreen() {
    if (_disposed) return;
    unawaited(preloadInterstitial());
    unawaited(preloadRewarded());
  }

  @override
  Future<BannerLoadResult> loadBanner(int width) async {
    final gate = await prepare();
    if (!gate.mayRequestAds) {
      return const BannerLoadResult(stopRetrying: true);
    }
    if (!gate.sdkReady) {
      return const BannerLoadResult(stopRetrying: false);
    }
    final completer = Completer<BannerAd?>();
    try {
      final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      final ad = BannerAd(
        adUnitId: unitIds.banner,
        size: size ?? AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (loaded) {
            if (!completer.isCompleted) completer.complete(loaded as BannerAd);
          },
          onAdFailedToLoad: (failed, error) {
            // The SDK requires disposing the failed instance. The banner
            // slot stays mounted and schedules its own retry.
            _log(
              formatAdFailure(
                'banner load',
                code: error.code,
                message: error.message,
              ),
            );
            failed.dispose();
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
      await ad.load();
      final loaded = await completer.future;
      return BannerLoadResult(ad: loaded, stopRetrying: false);
    } catch (error) {
      if (completer.isCompleted) {
        final loaded = await completer.future;
        return BannerLoadResult(ad: loaded, stopRetrying: false);
      }
      _logFailure('banner load', error);
      return const BannerLoadResult(stopRetrying: false);
    }
  }

  @override
  bool get isInterstitialReady => _interstitial != null;

  @override
  Future<void> preloadInterstitial() async {
    await _loadInterstitial();
  }

  Future<bool> _loadInterstitial() {
    if (_interstitial != null) return Future<bool>.value(true);
    return _interstitialLoad ??= _startInterstitialLoad().whenComplete(() {
      _interstitialLoad = null;
    });
  }

  Future<bool> _startInterstitialLoad() async {
    if (!_sdkReady || _disposed) return false;
    final completer = Completer<bool>();
    try {
      await InterstitialAd.load(
        adUnitId: unitIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (_disposed) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
              return;
            }
            _interstitial = ad;
            if (!completer.isCompleted) completer.complete(true);
          },
          onAdFailedToLoad: (error) {
            _log(
              formatAdFailure(
                'interstitial load',
                code: error.code,
                message: error.message,
              ),
            );
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
      return await completer.future;
    } catch (error) {
      _logFailure('interstitial load', error);
      if (!completer.isCompleted) completer.complete(false);
      return false;
    }
  }

  @override
  Future<bool> showInterstitial() async {
    final gate = await prepare();
    if (!gate.mayRequestAds || !gate.sdkReady) return false;
    final ad = _interstitial;
    if (ad == null) {
      unawaited(preloadInterstitial());
      return false;
    }
    _interstitial = null;
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete(true);
        unawaited(preloadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log(
          formatAdFailure(
            'interstitial show',
            code: error.code,
            message: error.message,
          ),
        );
        ad.dispose();
        if (!completer.isCompleted) completer.complete(false);
        unawaited(preloadInterstitial());
      },
    );
    try {
      await ad.show();
    } catch (error) {
      _logFailure('interstitial show', error);
      ad.dispose();
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  @override
  Future<bool> showRewarded() async {
    final gate = await prepare();
    if (!gate.mayRequestAds || !gate.sdkReady) return false;
    if (_rewarded == null) {
      try {
        await preloadRewarded().timeout(const Duration(seconds: 4));
      } on TimeoutException {
        _log(
          formatAdFailure(
            'rewarded load',
            code: 'timeout',
            message: 'gave up waiting; continuing without a reward',
          ),
        );
      }
    }
    final ad = _rewarded;
    if (ad == null) {
      _log(
        formatAdFailure(
          'rewarded show',
          code: 'not_ready',
          message: 'no rewarded ad loaded',
        ),
      );
      return false;
    }
    _rewarded = null;
    var earned = false;
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        // Closing early leaves [earned] false, so the reward is not granted.
        if (!completer.isCompleted) completer.complete(earned);
        unawaited(preloadRewarded());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log(
          formatAdFailure(
            'rewarded show',
            code: error.code,
            message: error.message,
          ),
        );
        ad.dispose();
        if (!completer.isCompleted) completer.complete(false);
        unawaited(preloadRewarded());
      },
    );
    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earned = true;
          _log(
            'AdMob rewarded earned: type=${reward.type} amount=${reward.amount}',
          );
        },
      );
    } catch (error) {
      _logFailure('rewarded show', error);
      ad.dispose();
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  Future<bool> preloadRewarded() {
    if (_rewarded != null) return Future<bool>.value(true);
    return _rewardedLoad ??= _startRewardedLoad().whenComplete(() {
      _rewardedLoad = null;
    });
  }

  Future<bool> _startRewardedLoad() async {
    if (!_sdkReady || _disposed) return false;
    final completer = Completer<bool>();
    try {
      await RewardedAd.load(
        adUnitId: unitIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (_disposed) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
              return;
            }
            _rewarded = ad;
            if (!completer.isCompleted) completer.complete(true);
          },
          onAdFailedToLoad: (error) {
            _log(
              formatAdFailure(
                'rewarded load',
                code: error.code,
                message: error.message,
              ),
            );
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
      return await completer.future;
    } catch (error) {
      _logFailure('rewarded load', error);
      if (!completer.isCompleted) completer.complete(false);
      return false;
    }
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    if (!_supported) return false;
    try {
      return await _consent.isPrivacyOptionsRequired();
    } catch (error) {
      _logFailure('privacy options', error);
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    if (!_supported) return;
    try {
      await _consent.showPrivacyOptions();
    } catch (error) {
      _logFailure('privacy options', error);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _interstitial?.dispose();
    _rewarded?.dispose();
    _interstitial = null;
    _rewarded = null;
  }

  void _logFailure(String stage, Object error) {
    if (error is PlatformException) {
      _log(
        formatAdFailure(
          stage,
          code: error.code,
          message: error.message ?? error.toString(),
        ),
      );
      return;
    }
    if (error is FormError) {
      _log(
        formatAdFailure(stage, code: error.errorCode, message: error.message),
      );
      return;
    }
    _log(formatAdFailure(stage, message: error.toString()));
  }
}

/// Google UMP. The consent form is shown only after a successful info update,
/// and that form is not timed out — it belongs to the user. A failed or
/// timed-out update still returns a snapshot so the caller can request ads
/// when the user has not denied consent.
class SdkConsentClient implements ConsentClient {
  SdkConsentClient({void Function(String message)? log})
    : _log = log ?? debugPrint;

  final void Function(String message) _log;

  static const _updateTimeout = Duration(seconds: 8);

  @override
  Future<ConsentSnapshot> gather() async {
    final update = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!update.isCompleted) update.complete(true);
      },
      (error) {
        _log(
          formatAdFailure(
            'consent info update',
            code: error.errorCode,
            message: error.message,
          ),
        );
        if (!update.isCompleted) update.complete(false);
      },
    );
    final updated = await update.future.timeout(
      _updateTimeout,
      onTimeout: () {
        _log(
          formatAdFailure(
            'consent info update',
            code: 'timeout',
            message: 'UMP requestConsentInfoUpdate timed out',
          ),
        );
        return false;
      },
    );

    if (updated) {
      try {
        final dismissed = Completer<void>();
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) {
            _log(
              formatAdFailure(
                'consent form',
                code: error.errorCode,
                message: error.message,
              ),
            );
          }
          if (!dismissed.isCompleted) dismissed.complete();
        });
        await dismissed.future;
      } catch (error) {
        _log(formatAdFailure('consent form', message: error.toString()));
      }
    }

    var status = ConsentStatusKind.unknown;
    bool? canRequest;
    try {
      status = _mapStatus(await ConsentInformation.instance.getConsentStatus());
    } catch (error) {
      _log(formatAdFailure('consent status', message: error.toString()));
    }
    try {
      canRequest = await ConsentInformation.instance.canRequestAds();
    } catch (error) {
      _log(formatAdFailure('canRequestAds', message: error.toString()));
      canRequest = null;
    }
    return ConsentSnapshot(
      updateCompleted: updated,
      status: status,
      canRequestAds: canRequest,
    );
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) {
        _log(
          formatAdFailure(
            'privacy options',
            code: error.errorCode,
            message: error.message,
          ),
        );
      }
      if (!done.isCompleted) done.complete();
    });
    await done.future;
  }

  static ConsentStatusKind _mapStatus(ConsentStatus status) => switch (status) {
    ConsentStatus.notRequired => ConsentStatusKind.notRequired,
    ConsentStatus.obtained => ConsentStatusKind.obtained,
    ConsentStatus.required => ConsentStatusKind.required,
    ConsentStatus.unknown => ConsentStatusKind.unknown,
  };
}
