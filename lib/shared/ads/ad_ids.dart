/// Google's public sample publisher. Any id containing this is a test id.
const samplePublisherId = '3940256099942544';

/// Official demo units. Debug and profile builds always use these.
/// https://developers.google.com/admob/android/test-ads
/// https://developers.google.com/admob/ios/test-ads
abstract final class AdTestIds {
  static const androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const androidBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const androidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const androidRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const iosAppId = 'ca-app-pub-3940256099942544~1458002511';
  static const iosBanner = 'ca-app-pub-3940256099942544/2435281174';
  static const iosInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const iosRewarded = 'ca-app-pub-3940256099942544/1712485313';
}

enum AdPlatform { android, ios }

class AdUnitIds {
  const AdUnitIds({
    required this.banner,
    required this.interstitial,
    required this.rewarded,
  });

  final String banner;
  final String interstitial;
  final String rewarded;

  static const testAndroid = AdUnitIds(
    banner: AdTestIds.androidBanner,
    interstitial: AdTestIds.androidInterstitial,
    rewarded: AdTestIds.androidRewarded,
  );

  static const testIos = AdUnitIds(
    banner: AdTestIds.iosBanner,
    interstitial: AdTestIds.iosInterstitial,
    rewarded: AdTestIds.iosRewarded,
  );
}

/// `ca-app-pub-` + 16 digit publisher + `~` (app id) or `/` (unit id) + 10 digits.
final RegExp productionAdIdShape = RegExp(r'^ca-app-pub-\d{16}[~\/]\d{10}$');

class InvalidReleaseAdIdException implements Exception {
  const InvalidReleaseAdIdException(this.label, this.value);

  final String label;
  final String value;

  @override
  String toString() =>
      'InvalidReleaseAdIdException: $label is a test id, placeholder, or '
      'malformed value: "$value"';
}

/// True when [raw] must not ship in a release build.
///
/// [requiredSeparator] is `~` for an app id and `/` for an ad unit. iOS TODO
/// placeholders fail this check; callers validate only the platform they are
/// about to ship so those placeholders do not fail an Android release.
bool isTestOrPlaceholderAdId(String raw, {String? requiredSeparator}) {
  final id = raw.trim();
  if (id.isEmpty) return true;
  final upper = id.toUpperCase();
  const blocked = ['TODO', 'PLACEHOLDER', 'XXXX', 'NNNN'];
  if (blocked.any(upper.contains)) return true;
  if (id.contains(samplePublisherId)) return true;
  if (!productionAdIdShape.hasMatch(id)) return true;
  if (requiredSeparator != null && !id.contains(requiredSeparator)) {
    return true;
  }
  return false;
}

/// Debug and profile always get [AdTestIds]. Release gets the production id
/// or throws — it never falls back to a test id.
String resolveAdUnitId({
  required bool releaseMode,
  required String productionId,
  required String testId,
  required String label,
  String? requiredSeparator,
}) {
  if (!releaseMode) return testId;
  if (isTestOrPlaceholderAdId(
    productionId,
    requiredSeparator: requiredSeparator,
  )) {
    throw InvalidReleaseAdIdException(label, productionId);
  }
  return productionId;
}

AdUnitIds resolveAdUnitIds({
  required bool releaseMode,
  required AdPlatform platform,
  required String banner,
  required String interstitial,
  required String rewarded,
}) {
  if (!releaseMode) {
    return platform == AdPlatform.ios
        ? AdUnitIds.testIos
        : AdUnitIds.testAndroid;
  }
  final prefix = platform == AdPlatform.ios ? 'ADMOB_IOS' : 'ADMOB_ANDROID';
  final test = platform == AdPlatform.ios
      ? AdUnitIds.testIos
      : AdUnitIds.testAndroid;
  return AdUnitIds(
    banner: resolveAdUnitId(
      releaseMode: true,
      productionId: banner,
      testId: test.banner,
      label: '${prefix}_BANNER_ID',
      requiredSeparator: '/',
    ),
    interstitial: resolveAdUnitId(
      releaseMode: true,
      productionId: interstitial,
      testId: test.interstitial,
      label: '${prefix}_INTERSTITIAL_ID',
      requiredSeparator: '/',
    ),
    rewarded: resolveAdUnitId(
      releaseMode: true,
      productionId: rewarded,
      testId: test.rewarded,
      label: '${prefix}_REWARDED_ID',
      requiredSeparator: '/',
    ),
  );
}
