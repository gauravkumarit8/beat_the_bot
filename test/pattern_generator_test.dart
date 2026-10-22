import 'dart:math';

import 'package:beat_the_bot/games/pattern/pattern_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every level makes a valid puzzle with 4 distinct options', () {
    for (var level = 1; level <= 5; level++) {
      for (var seed = 0; seed < 200; seed++) {
        final p = PatternGenerator(Random(seed)).generate(level);
        expect(p.shown.length, greaterThanOrEqualTo(4));
        expect(p.options.length, 4);
        expect(p.options.toSet().length, 4);
        expect(p.options, contains(p.answer));
        expect(p.options.every((o) => o > 0), isTrue);
      }
    }
  });

  test('level 1 is a constant difference', () {
    for (var seed = 0; seed < 100; seed++) {
      final p = PatternGenerator(Random(seed)).generate(1);
      final d = p.shown[1] - p.shown[0];
      for (var i = 1; i < p.shown.length; i++) {
        expect(p.shown[i] - p.shown[i - 1], d);
      }
      expect(p.answer, p.shown.last + d);
    }
  });

  test('level 2 multiplies by a constant', () {
    for (var seed = 0; seed < 100; seed++) {
      final p = PatternGenerator(Random(seed)).generate(2);
      final m = p.shown[1] ~/ p.shown[0];
      expect(p.answer, p.shown.last * m);
    }
  });

  test('level 5 adds the previous two numbers', () {
    for (var seed = 0; seed < 100; seed++) {
      final p = PatternGenerator(Random(seed)).generate(5);
      final n = p.shown.length;
      expect(p.answer, p.shown[n - 1] + p.shown[n - 2]);
    }
  });
}
