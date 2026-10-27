/// Banner reload delays after a failed load: 5s, 10s, 20s, 40s, then 60s.
Duration bannerRetryDelay(int failureCount) {
  final step = failureCount < 1 ? 1 : failureCount;
  final shift = (step - 1).clamp(0, 4);
  final seconds = 5 * (1 << shift);
  return Duration(seconds: seconds > 60 ? 60 : seconds);
}

/// Interstitials at natural breaks, at most every other break, and never
/// sooner than 90 seconds after session start or the previous impression.
class InterstitialPolicy {
  InterstitialPolicy({required this.startedAt});

  final DateTime startedAt;

  static const minInterval = Duration(seconds: 90);
  static const breaksBetweenShows = 2;

  int _breaksSinceShow = 0;
  DateTime? _lastShownAt;

  /// Records one natural break. True when an interstitial may be shown.
  /// A later [markShown] is what consumes the opportunity, so a break that
  /// is eligible while the ad is still loading can show on the next break.
  bool registerBreak(DateTime now) {
    _breaksSinceShow++;
    if (_breaksSinceShow < breaksBetweenShows) return false;
    final anchor = _lastShownAt ?? startedAt;
    if (now.difference(anchor) < minInterval) return false;
    return true;
  }

  void markShown(DateTime now) {
    _lastShownAt = now;
    _breaksSinceShow = 0;
  }
}
