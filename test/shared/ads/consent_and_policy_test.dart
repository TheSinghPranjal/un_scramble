import 'package:flutter_test/flutter_test.dart';
import 'package:un_scramble/shared/ads/ad_log.dart';
import 'package:un_scramble/shared/ads/ad_policy.dart';
import 'package:un_scramble/shared/ads/consent_decision.dart';

void main() {
  ConsentSnapshot snapshot({
    bool updateCompleted = true,
    ConsentStatusKind status = ConsentStatusKind.unknown,
    bool? canRequestAds = false,
    bool userDenied = false,
  }) {
    return ConsentSnapshot(
      updateCompleted: updateCompleted,
      status: status,
      canRequestAds: canRequestAds,
      userDenied: userDenied,
    );
  }

  test('timed-out UMP with canRequestAds false still requests ads', () {
    final decision = decideConsent(
      snapshot(
        updateCompleted: false,
        status: ConsentStatusKind.unknown,
        canRequestAds: false,
      ),
    );
    expect(decision, AdsConsentDecision.requestAds);
    expect(shouldAttemptSdkInitialization(decision), isTrue);
  });

  test('a failed consent read is not a denial', () {
    final decision = decideConsent(
      snapshot(
        updateCompleted: false,
        status: ConsentStatusKind.unknown,
        canRequestAds: null,
      ),
    );
    expect(decision, AdsConsentDecision.requestAds);
  });

  test('notRequired requests ads even when canRequestAds is false', () {
    final decision = decideConsent(
      snapshot(status: ConsentStatusKind.notRequired, canRequestAds: false),
    );
    expect(decision, AdsConsentDecision.requestAds);
  });

  test('obtained consent that cannot request ads is a denial', () {
    final decision = decideConsent(
      snapshot(status: ConsentStatusKind.obtained, canRequestAds: false),
    );
    expect(decision, AdsConsentDecision.consentDenied);
    expect(shouldAttemptSdkInitialization(decision), isFalse);
  });

  test('obtained consent that can request ads proceeds', () {
    expect(
      decideConsent(
        snapshot(status: ConsentStatusKind.obtained, canRequestAds: true),
      ),
      AdsConsentDecision.requestAds,
    );
  });

  test('required and not obtained skips ads', () {
    final decision = decideConsent(
      snapshot(
        updateCompleted: false,
        status: ConsentStatusKind.required,
        canRequestAds: true,
      ),
    );
    expect(decision, AdsConsentDecision.consentRequiredNotObtained);
    expect(shouldAttemptSdkInitialization(decision), isFalse);
  });

  test('an explicit denial skips ads', () {
    expect(
      decideConsent(
        snapshot(
          status: ConsentStatusKind.notRequired,
          canRequestAds: true,
          userDenied: true,
        ),
      ),
      AdsConsentDecision.consentDenied,
    );
  });

  test('banner retries back off and cap at 60 seconds', () {
    expect([1, 2, 3, 4, 5, 6].map((n) => bannerRetryDelay(n).inSeconds), [
      5,
      10,
      20,
      40,
      60,
      60,
    ]);
  });

  test('interstitials wait for two breaks and 90 seconds', () {
    final start = DateTime(2026, 1, 1, 12);
    final policy = InterstitialPolicy(startedAt: start);

    expect(policy.registerBreak(start), isFalse);
    expect(
      policy.registerBreak(start.add(const Duration(seconds: 89))),
      isFalse,
    );
    expect(
      policy.registerBreak(start.add(const Duration(seconds: 90))),
      isTrue,
    );
    policy.markShown(start.add(const Duration(seconds: 90)));

    expect(
      policy.registerBreak(start.add(const Duration(seconds: 91))),
      isFalse,
    );
    expect(
      policy.registerBreak(start.add(const Duration(seconds: 180))),
      isTrue,
    );
  });

  test('failure logs include a code and a message', () {
    expect(
      formatAdFailure('init', code: 'internal', message: 'boom'),
      'AdMob init failed: code=internal message=boom',
    );
    expect(
      formatAdFailure('consent info update', code: 3, message: 'no form'),
      'AdMob consent info update failed: code=3 message=no form',
    );
  });
}
