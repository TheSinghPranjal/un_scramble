/// One line for logcat. Every init, consent, and load failure goes through
/// this so the code and message are never dropped.
String formatAdFailure(String stage, {Object? code, required String message}) {
  return 'AdMob $stage failed: code=${code ?? 'n/a'} message=$message';
}
