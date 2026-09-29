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

Monetization hooks are disabled stubs marked `TODO(monetization)` in the hint sheet and the lose dialog.
