import 'dart:convert';

import 'package:flutter/services.dart';

import 'ad_ids.dart';

/// Production AdMob ids bundled with the app. Debug and profile builds do not
/// send these to the SDK; release builds reject the file if an id for the
/// platform being shipped is a test id or a placeholder.
class AdmobConfig {
  const AdmobConfig({
    required this.androidAppId,
    required this.androidBannerId,
    required this.androidInterstitialId,
    required this.androidRewardedId,
    required this.iosAppId,
    required this.iosBannerId,
    required this.iosInterstitialId,
    required this.iosRewardedId,
  });

  static const assetPath = 'config/admob.json';

  final String androidAppId;
  final String androidBannerId;
  final String androidInterstitialId;
  final String androidRewardedId;
  final String iosAppId;
  final String iosBannerId;
  final String iosInterstitialId;
  final String iosRewardedId;

  factory AdmobConfig.fromJson(Map<String, dynamic> json) {
    String read(String key) {
      final value = json[key];
      return value is String ? value.trim() : '';
    }

    return AdmobConfig(
      androidAppId: read('ADMOB_ANDROID_APP_ID'),
      androidBannerId: read('ADMOB_ANDROID_BANNER_ID'),
      androidInterstitialId: read('ADMOB_ANDROID_INTERSTITIAL_ID'),
      androidRewardedId: read('ADMOB_ANDROID_REWARDED_ID'),
      iosAppId: read('ADMOB_IOS_APP_ID'),
      iosBannerId: read('ADMOB_IOS_BANNER_ID'),
      iosInterstitialId: read('ADMOB_IOS_INTERSTITIAL_ID'),
      iosRewardedId: read('ADMOB_IOS_REWARDED_ID'),
    );
  }

  /// Checks every id the [platform] release build will actually use.
  /// iOS TODO placeholders are not read when [platform] is Android.
  void validateForRelease(AdPlatform platform) {
    final entries = switch (platform) {
      AdPlatform.android => {
        'ADMOB_ANDROID_APP_ID': (androidAppId, '~'),
        'ADMOB_ANDROID_BANNER_ID': (androidBannerId, '/'),
        'ADMOB_ANDROID_INTERSTITIAL_ID': (androidInterstitialId, '/'),
        'ADMOB_ANDROID_REWARDED_ID': (androidRewardedId, '/'),
      },
      AdPlatform.ios => {
        'ADMOB_IOS_APP_ID': (iosAppId, '~'),
        'ADMOB_IOS_BANNER_ID': (iosBannerId, '/'),
        'ADMOB_IOS_INTERSTITIAL_ID': (iosInterstitialId, '/'),
        'ADMOB_IOS_REWARDED_ID': (iosRewardedId, '/'),
      },
    };
    for (final entry in entries.entries) {
      final (value, separator) = entry.value;
      if (isTestOrPlaceholderAdId(value, requiredSeparator: separator)) {
        throw InvalidReleaseAdIdException(entry.key, value);
      }
    }
  }

  AdUnitIds unitIds({required bool releaseMode, required AdPlatform platform}) {
    final production = platform == AdPlatform.ios
        ? (
            banner: iosBannerId,
            interstitial: iosInterstitialId,
            rewarded: iosRewardedId,
          )
        : (
            banner: androidBannerId,
            interstitial: androidInterstitialId,
            rewarded: androidRewardedId,
          );
    return resolveAdUnitIds(
      releaseMode: releaseMode,
      platform: platform,
      banner: production.banner,
      interstitial: production.interstitial,
      rewarded: production.rewarded,
    );
  }
}

Future<AdmobConfig> loadAdmobConfig(AssetBundle bundle) async {
  final raw = await bundle.loadString(AdmobConfig.assetPath);
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('config/admob.json must be a JSON object');
  }
  return AdmobConfig.fromJson(Map<String, dynamic>.from(decoded));
}
