import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:un_scramble/shared/ads/ad_ids.dart';
import 'package:un_scramble/shared/ads/ad_service.dart';
import 'package:un_scramble/shared/ads/admob_config.dart';
import 'package:un_scramble/shared/ads/consent_decision.dart';

class _Consent implements ConsentClient {
  _Consent(this.snapshot, {this.blowUp = false});

  final ConsentSnapshot snapshot;
  final bool blowUp;
  int gathers = 0;

  @override
  Future<ConsentSnapshot> gather() async {
    gathers++;
    if (blowUp) throw StateError('ump down');
    return snapshot;
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

void main() {
  const config = AdmobConfig(
    androidAppId: 'ca-app-pub-8661918790125012~3957171192',
    androidBannerId: 'ca-app-pub-8661918790125012/7856761447',
    androidInterstitialId: 'ca-app-pub-8661918790125012/9499026503',
    androidRewardedId: 'ca-app-pub-8661918790125012/3670230734',
    iosAppId: 'TODO_IOS_APP_ID',
    iosBannerId: 'TODO_IOS_BANNER_ID',
    iosInterstitialId: 'TODO_IOS_INTERSTITIAL_ID',
    iosRewardedId: 'TODO_IOS_REWARDED_ID',
  );

  GoogleMobileAdsService service({
    required _Consent consent,
    required List<String> logs,
    required List<int> inits,
    int failInits = 0,
    bool releaseMode = false,
    AdPlatform platform = AdPlatform.android,
    AdmobConfig? loaded = config,
  }) {
    return GoogleMobileAdsService(
      supported: true,
      releaseMode: releaseMode,
      platform: platform,
      consentClient: consent,
      loadConfig: () async => loaded,
      log: logs.add,
      preloadAfterInit: false,
      initializeSdk: () async {
        inits.add(inits.length + 1);
        if (inits.length <= failInits) {
          throw PlatformException(code: 'internal', message: 'boom');
        }
      },
    );
  }

  test('a timed-out UMP check still initializes the SDK', () async {
    final logs = <String>[];
    final inits = <int>[];
    final gate = await service(
      consent: _Consent(
        const ConsentSnapshot(
          updateCompleted: false,
          status: ConsentStatusKind.unknown,
          canRequestAds: false,
        ),
      ),
      logs: logs,
      inits: inits,
    ).prepare();

    expect(gate.mayRequestAds, isTrue);
    expect(gate.sdkReady, isTrue);
    expect(inits, [1]);
    expect(logs.any((line) => line.contains('AdMob init succeeded')), isTrue);
  });

  test('a thrown consent check still initializes', () async {
    final logs = <String>[];
    final inits = <int>[];
    final gate = await service(
      consent: _Consent(
        const ConsentSnapshot(
          updateCompleted: false,
          status: ConsentStatusKind.unknown,
          canRequestAds: false,
        ),
        blowUp: true,
      ),
      logs: logs,
      inits: inits,
    ).prepare();

    expect(gate.mayRequestAds, isTrue);
    expect(gate.sdkReady, isTrue);
    expect(inits, [1]);
    expect(
      logs.any(
        (line) =>
            line.contains('consent check failed') &&
            line.contains('code=n/a') &&
            line.contains('ump down'),
      ),
      isTrue,
    );
  });

  test('denied or required consent does not initialize', () async {
    for (final snapshot in [
      const ConsentSnapshot(
        updateCompleted: true,
        status: ConsentStatusKind.obtained,
        canRequestAds: false,
      ),
      const ConsentSnapshot(
        updateCompleted: true,
        status: ConsentStatusKind.required,
        canRequestAds: false,
      ),
    ]) {
      final inits = <int>[];
      final gate = await service(
        consent: _Consent(snapshot),
        logs: [],
        inits: inits,
      ).prepare();
      expect(gate.mayRequestAds, isFalse);
      expect(gate.sdkReady, isFalse);
      expect(inits, isEmpty);
    }
  });

  test('an init exception is logged and a later attempt can succeed', () async {
    final logs = <String>[];
    final inits = <int>[];
    final ads = service(
      consent: _Consent(
        const ConsentSnapshot(
          updateCompleted: true,
          status: ConsentStatusKind.notRequired,
          canRequestAds: true,
        ),
      ),
      logs: logs,
      inits: inits,
      failInits: 1,
    );

    final first = await ads.prepare();
    expect(first.mayRequestAds, isTrue);
    expect(first.sdkReady, isFalse);
    expect(
      logs.any(
        (line) =>
            line.contains('init failed') &&
            line.contains('code=internal') &&
            line.contains('message=boom'),
      ),
      isTrue,
    );

    final second = await ads.prepare();
    expect(second.sdkReady, isTrue);
    expect(inits, [1, 2]);
  });

  test('Android release accepts real ids and still initializes', () async {
    final inits = <int>[];
    final ads = service(
      consent: _Consent(
        const ConsentSnapshot(
          updateCompleted: true,
          status: ConsentStatusKind.notRequired,
          canRequestAds: true,
        ),
      ),
      logs: [],
      inits: inits,
      releaseMode: true,
    );
    final gate = await ads.prepare();
    expect(gate.configRejected, isFalse);
    expect(gate.sdkReady, isTrue);
    expect(ads.unitIds.banner, config.androidBannerId);
    expect(ads.unitIds.banner, isNot(AdTestIds.androidBanner));
  });

  test('debug never exposes the production unit id', () async {
    final ads = service(
      consent: _Consent(
        const ConsentSnapshot(
          updateCompleted: true,
          status: ConsentStatusKind.notRequired,
          canRequestAds: true,
        ),
      ),
      logs: [],
      inits: [],
    );
    await ads.prepare();
    expect(ads.unitIds.banner, AdTestIds.androidBanner);
    expect(ads.unitIds.interstitial, AdTestIds.androidInterstitial);
    expect(ads.unitIds.rewarded, AdTestIds.androidRewarded);
  });

  test('iOS TODO placeholders do not reject an Android release', () async {
    final android = service(
      consent: _Consent(
        const ConsentSnapshot(
          updateCompleted: true,
          status: ConsentStatusKind.notRequired,
          canRequestAds: true,
        ),
      ),
      logs: [],
      inits: [],
      releaseMode: true,
      platform: AdPlatform.android,
    );
    expect((await android.prepare()).configRejected, isFalse);

    final logs = <String>[];
    final inits = <int>[];
    final ios = service(
      consent: _Consent(
        const ConsentSnapshot(
          updateCompleted: true,
          status: ConsentStatusKind.notRequired,
          canRequestAds: true,
        ),
      ),
      logs: logs,
      inits: inits,
      releaseMode: true,
      platform: AdPlatform.ios,
    );
    final gate = await ios.prepare();
    expect(gate.configRejected, isTrue);
    expect(gate.mayRequestAds, isFalse);
    expect(inits, isEmpty);
    expect(logs.any((line) => line.contains('code=invalid_id')), isTrue);
  });
}
