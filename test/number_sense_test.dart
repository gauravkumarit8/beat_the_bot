import 'dart:math';

import 'package:beat_the_bot/core/difficulty.dart';
import 'package:beat_the_bot/games/quiz/quiz_specs.dart';
import 'package:flutter_test/flutter_test.dart';

double _parse(String label) {
  if (label.endsWith('%')) {
    return double.parse(label.substring(0, label.length - 1)) / 100;
  }
  if (label.contains('/')) {
    final parts = label.split('/');
    return double.parse(parts[0]) / double.parse(parts[1]);
  }
  return double.parse(label);
}

void main() {
  test('Number Sense always has exactly one right answer', () {
    const spec = NumberSenseSpec();
    for (final level in Level.values) {
      for (var seed = 0; seed < 200; seed++) {
        final q = spec.question(
          round: 1 + seed % 10,
          level: level,
          rng: Random(seed),
        );
        expect(q.options.length, level == Level.hard ? 4 : 3);
        expect(q.options.map((o) => o.label).toSet().length, q.options.length);
        final values = [for (final o in q.options) _parse(o.label)];
        final expected = q.prompt == 'SMALLEST?'
            ? values.reduce(min)
            : values.reduce(max);
        expect(values[q.answer], expected);
        expect(values.where((v) => v == expected).length, 1);
      }
    }
  });
}
