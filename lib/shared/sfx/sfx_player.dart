import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sound-effect hooks. The MVP ships silent; swap in a real implementation
/// (e.g. audioplayers / just_audio) by overriding [sfxPlayerProvider].
abstract interface class SfxPlayer {
  void playCorrect();
  void playWrong();
  void playWin();
  void playLose();
  void playTick();
}

class NoopSfxPlayer implements SfxPlayer {
  const NoopSfxPlayer();

  @override
  void playCorrect() {}
  @override
  void playWrong() {}
  @override
  void playWin() {}
  @override
  void playLose() {}
  @override
  void playTick() {}
}

final sfxPlayerProvider = Provider<SfxPlayer>((ref) => const NoopSfxPlayer());
