import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with a loaded instance (and in tests with a mock).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

class HighScoreNotifier extends Notifier<int> {
  static const _key = 'high_score';

  @override
  int build() => ref.watch(sharedPreferencesProvider).getInt(_key) ?? 0;

  void submit(int score) {
    if (score <= state) return;
    state = score;
    ref.read(sharedPreferencesProvider).setInt(_key, score);
  }
}

final highScoreProvider = NotifierProvider<HighScoreNotifier, int>(
  HighScoreNotifier.new,
);

class CoachMarksSeenNotifier extends Notifier<bool> {
  static const _key = 'coach_marks_seen';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  void markSeen() {
    state = true;
    ref.read(sharedPreferencesProvider).setBool(_key, true);
  }
}

final coachMarksSeenProvider = NotifierProvider<CoachMarksSeenNotifier, bool>(
  CoachMarksSeenNotifier.new,
);
