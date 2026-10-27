import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:un_scramble/shared/ads/ad_ids.dart';
import 'package:un_scramble/shared/ads/admob_config.dart';

void main() {
  const androidApp = 'ca-app-pub-8661918790125012~3957171192';
  const androidBanner = 'ca-app-pub-8661918790125012/7856761447';
  const androidInterstitial = 'ca-app-pub-8661918790125012/9499026503';
  const androidRewarded = 'ca-app-pub-8661918790125012/3670230734';

  AdmobConfig realConfig() => const AdmobConfig(
    androidAppId: androidApp,
    androidBannerId: androidBanner,
    androidInterstitialId: androidInterstitial,
    androidRewardedId: androidRewarded,
    iosAppId: 'TODO_IOS_APP_ID',
    iosBannerId: 'TODO_IOS_BANNER_ID',
    iosInterstitialId: 'TODO_IOS_INTERSTITIAL_ID',
    iosRewardedId: 'TODO_IOS_REWARDED_ID',
  );

  test('bundled config/admob.json has the owner Android ids', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fromDisk = AdmobConfig.fromJson(
      jsonDecode(File('config/admob.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final fromBundle = await loadAdmobConfig(rootBundle);

    for (final config in [fromDisk, fromBundle]) {
      expect(config.androidAppId, androidApp);
      expect(config.androidBannerId, androidBanner);
      expect(config.androidInterstitialId, androidInterstitial);
      expect(config.androidRewardedId, androidRewarded);
      expect(config.androidAppId, contains('8661918790125012'));
      expect(config.iosAppId, contains('TODO'));
      expect(config.iosBannerId, contains('TODO'));
      expect(isTestOrPlaceholderAdId(config.iosBannerId), isTrue);
      expect(
        isTestOrPlaceholderAdId(config.androidBannerId, requiredSeparator: '/'),
        isFalse,
      );
    }
  });

  test('debug and profile resolve to Google test ids', () {
    final ids = realConfig().unitIds(
      releaseMode: false,
      platform: AdPlatform.android,
    );
    expect(ids.banner, AdTestIds.androidBanner);
    expect(ids.interstitial, AdTestIds.androidInterstitial);
    expect(ids.rewarded, AdTestIds.androidRewarded);
    expect(ids.banner, isNot(androidBanner));

    final ios = realConfig().unitIds(
      releaseMode: false,
      platform: AdPlatform.ios,
    );
    expect(ios.banner, AdTestIds.iosBanner);
    expect(ios.banner, isNot(contains('TODO')));
  });

  test('Android release uses production ids and ignores iOS placeholders', () {
    final config = realConfig();
    expect(
      () => config.validateForRelease(AdPlatform.android),
      returnsNormally,
    );
    final ids = config.unitIds(releaseMode: true, platform: AdPlatform.android);
    expect(ids.banner, androidBanner);
    expect(ids.interstitial, androidInterstitial);
    expect(ids.rewarded, androidRewarded);
  });

  test('iOS release rejects TODO placeholders', () {
    expect(
      () => realConfig().validateForRelease(AdPlatform.ios),
      throwsA(
        isA<InvalidReleaseAdIdException>().having(
          (error) => error.label,
          'label',
          'ADMOB_IOS_APP_ID',
        ),
      ),
    );
  });

  test('Android manifest and Gradle wire the bundled config', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('com.google.android.gms.ads.APPLICATION_ID'));
    expect(manifest, contains('\${admobAppId}'));

    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('config/admob.json'));
    expect(gradle, contains('ADMOB_ANDROID_APP_ID'));
    expect(gradle, contains(AdTestIds.androidAppId));
    expect(gradle, contains('3940256099942544'));

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('config/admob.json'));
    expect(pubspec, contains('google_mobile_ads:'));
  });

  test('release rejects Google test ids and placeholders', () {
    expect(
      isTestOrPlaceholderAdId(AdTestIds.androidBanner, requiredSeparator: '/'),
      isTrue,
    );
    expect(
      isTestOrPlaceholderAdId(AdTestIds.androidAppId, requiredSeparator: '~'),
      isTrue,
    );
    expect(isTestOrPlaceholderAdId(''), isTrue);
    expect(
      isTestOrPlaceholderAdId('ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN'),
      isTrue,
    );
    expect(
      isTestOrPlaceholderAdId(
        'ca-app-pub-8661918790125012~3957171192',
        requiredSeparator: '/',
      ),
      isTrue,
      reason: 'an app id is not a unit id',
    );

    expect(
      () => resolveAdUnitId(
        releaseMode: true,
        productionId: AdTestIds.androidRewarded,
        testId: AdTestIds.androidRewarded,
        label: 'ADMOB_ANDROID_REWARDED_ID',
        requiredSeparator: '/',
      ),
      throwsA(isA<InvalidReleaseAdIdException>()),
    );
  });
}
