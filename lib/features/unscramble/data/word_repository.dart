import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';

abstract interface class WordRepository {
  Future<List<WordEntry>> loadWords();
}

/// Reads the bundled word list from `assets/words/words.json`.
class AssetWordRepository implements WordRepository {
  AssetWordRepository(this._bundle, {this.path = 'assets/words/words.json'});

  final AssetBundle _bundle;
  final String path;

  @override
  Future<List<WordEntry>> loadWords() async {
    final raw = await _bundle.loadString(path);
    final decoded = jsonDecode(raw) as List<dynamic>;
    final entries = decoded
        .cast<Map<String, dynamic>>()
        .map(WordEntry.fromJson)
        .toList();
    assert(
      entries.every((e) => e.isValid),
      'words.json contains invalid words: '
      '${entries.where((e) => !e.isValid).map((e) => e.word).toList()}',
    );
    // Drop anything invalid in release rather than crash mid-round.
    return entries.where((e) => e.isValid).toList(growable: false);
  }
}

/// Deals words without repeats until every word has been used, then reshuffles.
class WordDeck {
  WordDeck(List<WordEntry> words, this._random)
    : assert(words.isNotEmpty, 'WordDeck needs at least one word'),
      _all = List.unmodifiable(words);

  final List<WordEntry> _all;
  final Random _random;
  final List<WordEntry> _remaining = [];

  WordEntry next() {
    if (_remaining.isEmpty) {
      final previous = _lastDealt;
      _remaining
        ..addAll(_all)
        ..shuffle(_random);
      // Avoid dealing the same word twice in a row across a reshuffle.
      if (_remaining.length > 1 && _remaining.last == previous) {
        _remaining.insert(0, _remaining.removeLast());
      }
    }
    return _lastDealt = _remaining.removeLast();
  }

  WordEntry? _lastDealt;
}

final wordRepositoryProvider = Provider<WordRepository>(
  (ref) => AssetWordRepository(rootBundle),
);

final wordListProvider = FutureProvider<List<WordEntry>>(
  (ref) => ref.watch(wordRepositoryProvider).loadWords(),
);
