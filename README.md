# Unscramble

A casual word puzzle built with Flutter and Riverpod. Drag (or tap) scrambled letters into the answer slots to rebuild the hidden word. A wrong letter costs a life. You get 10 lives, one for each letter of **UNSCRAMBLE**, and 2:00 on the clock. After 2 mistakes you get one free hint.

## Run

```bash
flutter pub get
flutter run            # pick an Android device/emulator
flutter test           # controller rules, life bar, word list, game screen
```

Fonts (Fredoka, Nunito) come from `google_fonts`. They download on first launch and are then cached. The app declares the `INTERNET` permission for this. If you want fonts to work fully offline, bundle the `.ttf` files under `assets/google_fonts/`.

## Adding words

Edit `assets/words/words.json`:

```json
{ "word": "TIGER", "category": "Animals", "hintText": "Big striped cat", "difficulty": "easy" }
```

- `word`: 4–8 letters, A–Z only, no spaces. It is upper-cased on load.
- `category`: shown in the chip above the slots.
- `hintText` (optional): clue shown in the hint sheet.
- `difficulty` (optional): `easy` | `medium` | `hard`. Defaults to `easy`.

Invalid entries fail an assert in debug builds and are skipped in release builds. `test/features/unscramble/word_list_test.dart` checks the whole file, so run `flutter test` after editing. Words are dealt without repeats until the deck runs out, then it reshuffles.

## Architecture

```
lib/
  main.dart / app.dart                 ProviderScope, SharedPreferences, theme
  features/unscramble/
    domain/models.dart                 LetterTile, GameStatus, UnscrambleGameState…
    data/word_repository.dart          asset loader + WordDeck
    application/unscramble_controller.dart   all game rules (Notifier)
    presentation/                      HomeScreen, GameScreen, widgets/
  shared/
    sfx/sfx_player.dart                no-op sound hooks
    prefs/preferences.dart             high score + coach-mark flag
    theme/app_theme.dart               Material 3 light/dark + GameColors
```

`UnscrambleController` owns every rule. Widgets only call its methods. UI feedback (flashes, shakes, haptics) is driven by `state.lastEvent`, a one-shot event with an increasing `serial`.

```
lib/shared/ads/          AdMob config, UMP consent, banner, interstitial, rewarded
config/admob.json        production ids, bundled as a Flutter asset
```

## Ads

Release builds request the production Android units in `config/admob.json` (publisher `pub-8661918790125012`). Debug and profile builds always use Google's test app id and test ad units, even though the production ids are in the asset.

- A banner stays on the home and game screens and retries after a failed load (5s, 10s, 20s, 40s, then 60s).
- An interstitial can show between rounds (next word or retry), at most every other break and never twice within 90 seconds. If it is not loaded, play continues. The player can close it.
- A rewarded ad grants one extra letter on the hint sheet, one extra life after running out, or 30 extra seconds after a timeout. Closing it early grants nothing. If it is not available, the round continues.

Android `applicationId` / namespace: `com.the_lazy_bear_club.un_scramble`. The iOS bundle id is different (`com.thelazybearclub.unScramble`). iOS ids in `config/admob.json` are TODO placeholders and are not read for Android release builds.

Before a Play release, confirm the AdMob app is registered for `com.the_lazy_bear_club.un_scramble`, publish a Privacy & messaging (UMP) message, and host a privacy policy URL. A missing UMP message does not turn ads off. Replace the iOS TODO ids and `GADApplicationIdentifier` before shipping iOS. Build a release app bundle with `flutter build appbundle`; do not pass dart-defines. The release manifest app id is injected from `config/admob.json`, and the Gradle build rejects test or placeholder Android ids.
