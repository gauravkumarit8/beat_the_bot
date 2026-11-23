import 'dart:math';

import 'package:beat_the_bot/core/difficulty.dart';
import 'package:beat_the_bot/games/quiz/quiz_specs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => ColorClashSpec.markers = false);

  test('without help the labels are just colour names', () {
    ColorClashSpec.markers = false;
    final q = const ColorClashSpec()
        .question(round: 1, level: Level.medium, rng: Random(1));
    for (final o in q.options) {
      expect(ColorClashSpec.palette.any((c) => c.name == o.label), isTrue);
    }
  });

  test('with help every colour carries its shape and the answer is right', () {
    ColorClashSpec.markers = true;
    const spec = ColorClashSpec();
    for (final level in Level.values) {
      for (var seed = 0; seed < 150; seed++) {
        final q = spec.question(
            round: 1 + seed % 10, level: level, rng: Random(seed));
        final word = q.prompt.split(' ').first;
        final ink = ColorClashSpec.palette
            .firstWhere((c) => c.color == q.promptColor);
        expect(q.prompt, '$word ${ink.mark}');
        for (final o in q.options) {
          final c = ColorClashSpec.palette
              .firstWhere((c) => o.label == '${c.mark} ${c.name}');
          expect(c, isNotNull);
        }
        final target = q.hint.contains('WORD') ? word : ink.name;
        expect(q.options[q.answer].label.endsWith(target), isTrue);
      }
    }
  });
}
