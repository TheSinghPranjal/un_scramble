/// UMP outcome, independent of the plugin so it can be tested.
///
/// A sibling app shipped with zero ad requests because it initialized the
/// Mobile Ads SDK only when `canRequestAds()` was already true. A failed or
/// timed-out consent update (normal when no European-regulations message is
/// published, and for many non-EEA users) leaves that flag false and the
/// status unknown. That is not a denial. Ads are skipped only when consent
/// was actually denied, or when it is required and has not been obtained.
enum ConsentStatusKind { unknown, required, notRequired, obtained }

enum AdsConsentDecision {
  requestAds,
  consentDenied,
  consentRequiredNotObtained,
}

class ConsentSnapshot {
  const ConsentSnapshot({
    required this.updateCompleted,
    required this.status,
    required this.canRequestAds,
    this.userDenied = false,
  });

  /// False when `requestConsentInfoUpdate` failed or timed out.
  final bool updateCompleted;

  /// Cached status is still readable after a failed refresh.
  final ConsentStatusKind status;

  /// Null when the read itself failed. A `false` value is ignored unless the
  /// status is [ConsentStatusKind.obtained] — a false flag with an unknown
  /// status is the timed-out UMP case and must still request ads.
  final bool? canRequestAds;

  /// Explicit denial, if a caller knows one beyond the status enum.
  final bool userDenied;
}

bool shouldAttemptSdkInitialization(AdsConsentDecision decision) =>
    decision == AdsConsentDecision.requestAds;

AdsConsentDecision decideConsent(ConsentSnapshot snapshot) {
  if (snapshot.userDenied) return AdsConsentDecision.consentDenied;

  // Required and the user has not made a choice. Do not request ads.
  if (snapshot.status == ConsentStatusKind.required) {
    return AdsConsentDecision.consentRequiredNotObtained;
  }

  // A completed choice that does not allow requests is a denial.
  if (snapshot.status == ConsentStatusKind.obtained &&
      snapshot.canRequestAds == false) {
    return AdsConsentDecision.consentDenied;
  }

  // notRequired, obtained + ads allowed, or unknown after a failure/timeout
  // where the user has not denied: request ads.
  return AdsConsentDecision.requestAds;
}
