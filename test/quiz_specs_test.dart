import 'dart:math';

import 'package:beat_the_bot/core/difficulty.dart';
import 'package:beat_the_bot/games/quiz/quiz_specs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const specs = <QuizSpec>[MathRushSpec(), ColorClashSpec()];

  test('every question has distinct options and a valid answer', () {
    for (final spec in specs) {
      for (final level in Level.values) {
        for (var round = 1; round <= spec.rounds; round++) {
          for (var seed = 0; seed < 40; seed++) {
            final q = spec.question(round: round, level: level, rng: Random(seed));
            final labels = [for (final o in q.options) o.label];
            expect(labels.toSet().length, labels.length);
            expect(labels.length, greaterThanOrEqualTo(3));
            expect(q.answer, inInclusiveRange(0, labels.length - 1));
          }
        }
      }
    }
  });

  test('Math Rush marks the right sum as the answer', () {
    final pattern = RegExp(r'^(\d+) ([+\-×÷]) (\d+) = \?$');
    for (final level in Level.values) {
      for (var round = 1; round <= 10; round++) {
        for (var seed = 0; seed < 60; seed++) {
          final q = const MathRushSpec()
              .question(round: round, level: level, rng: Random(seed));
          final m = pattern.firstMatch(q.prompt)!;
          final a = int.parse(m.group(1)!);
          final b = int.parse(m.group(3)!);
          final int result;
          switch (m.group(2)) {
            case '+':
              result = a + b;
            case '-':
              result = a - b;
            case '×':
              result = a * b;
            default:
              expect(a % b, 0);
              result = a ~/ b;
          }
          expect(result, greaterThanOrEqualTo(0));
          expect(q.options[q.answer].label, '$result');
        }
      }
    }
  });

  test('Color Clash asks for the ink or the word and marks it correctly', () {
    for (final level in Level.values) {
      for (var round = 1; round <= 10; round++) {
        for (var seed = 0; seed < 60; seed++) {
          final q = const ColorClashSpec()
              .question(round: round, level: level, rng: Random(seed));
          final inkName = ColorClashSpec.palette
              .firstWhere((c) => c.color == q.promptColor)
              .name;
          final expected = q.hint.contains('INK') ? inkName : q.prompt;
          expect(q.options[q.answer].label, expected);
          if (level != Level.hard) expect(q.hint, contains('INK'));
        }
      }
    }
  });

  test('the same seed always gives the same question', () {
    for (final spec in specs) {
      final a = spec.question(round: 4, level: Level.medium, rng: Random(7));
      final b = spec.question(round: 4, level: Level.medium, rng: Random(7));
      expect(a.prompt, b.prompt);
      expect([for (final o in a.options) o.label],
          [for (final o in b.options) o.label]);
    }
  });
}
