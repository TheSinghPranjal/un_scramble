import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:un_scramble/features/unscramble/domain/models.dart';

void main() {
  test('words.json has 50+ valid 4–8 letter A–Z words, no duplicates', () {
    final raw = File('assets/words/words.json').readAsStringSync();
    final entries = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(WordEntry.fromJson)
        .toList();

    expect(entries.length, greaterThanOrEqualTo(50));
    for (final e in entries) {
      expect(e.isValid, isTrue, reason: '${e.word} is not 4–8 letters A–Z');
    }
    final words = entries.map((e) => e.word).toList();
    expect(words.toSet().length, words.length, reason: 'duplicate words');
  });
}
