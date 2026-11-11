import 'dart:math';

import 'package:flutter/painting.dart' show Color;

import '../../core/difficulty.dart';

class QuizOption {
  const QuizOption(this.label);

  final String label;
}

/// One question: a prompt, some options, and which option is right.
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.answer,
    this.promptColor,
    this.hint = '',
  });

  final String prompt;
  final Color? promptColor;
  final List<QuizOption> options;

  /// Index into [options].
  final int answer;
  final String hint;
}

/// Describes a quick "pick the right answer" brain game. One screen plays
/// every spec, so new games are cheap to add.
abstract class QuizSpec {
  const QuizSpec();

  /// Short id used for saving scores: math or color.
  String get id;
  String get title;
  String get intro;
  String get opening;
  int get rounds => 10;

  Duration timeFor(Level level);

  /// Chance that Zed answers a round correctly.
  double zedAccuracy(Level level);

  QuizQuestion question({
    required int round,
    required Level level,
    required Random rng,
  });
}

/// Mental arithmetic against the clock.
class MathRushSpec extends QuizSpec {
  const MathRushSpec();

  @override
  String get id => 'math';

  @override
  String get title => 'Math Rush';

  @override
  String get intro =>
      'Solve each sum in your head before the clock runs out. Ten questions.';

  @override
  String get opening => 'I compute faster than you blink.';

  @override
  Duration timeFor(Level level) => switch (level) {
        Level.easy => const Duration(seconds: 7),
        Level.medium => const Duration(seconds: 5),
        Level.hard => const Duration(seconds: 4),
      };

  @override
  double zedAccuracy(Level level) => switch (level) {
        Level.easy => 0.7,
        Level.medium => 0.8,
        Level.hard => 0.9,
      };

  @override
  QuizQuestion question({
    required int round,
    required Level level,
    required Random rng,
  }) {
    final easy = level == Level.easy;
    final hard = level == Level.hard;
    final ops = easy
        ? const ['+', '-']
        : (hard ? const ['+', '-', '×', '÷'] : const ['+', '-', '×']);
    // The first two rounds are gentle: only plus and minus.
    final op = round <= 2 ? ops[rng.nextInt(2)] : ops[rng.nextInt(ops.length)];
    final maxN = easy ? 20 : (hard ? 99 : 60);
    final top = hard ? 12 : 9;

    int a;
    int b;
    int answer;
    switch (op) {
      case '+':
        a = 2 + rng.nextInt(maxN - 1);
        b = 2 + rng.nextInt(maxN - 1);
        answer = a + b;
      case '-':
        a = 6 + rng.nextInt(maxN);
        b = 1 + rng.nextInt(a - 1);
        answer = a - b;
      case '×':
        a = 2 + rng.nextInt(top - 1);
        b = 2 + rng.nextInt(top - 1);
        answer = a * b;
      default:
        b = 2 + rng.nextInt(hard ? 11 : 8);
        answer = 2 + rng.nextInt(hard ? 12 : 9);
        a = b * answer;
    }

    final count = hard ? 4 : 3;
    const deltas = [1, -1, 2, -2, 10, -10, 3, -3, 5, -5];
    final wrong = <int>{};
    while (wrong.length < count - 1) {
      final v = answer + deltas[rng.nextInt(deltas.length)];
      if (v >= 0 && v != answer) wrong.add(v);
    }
    final values = [answer, ...wrong]..shuffle(rng);
    return QuizQuestion(
      prompt: '$a $op $b = ?',
      options: [for (final v in values) QuizOption('$v')],
      answer: values.indexOf(answer),
    );
  }
}

class ClashColor {
  const ClashColor(this.name, this.color);

  final String name;
  final Color color;
}

/// The Stroop test: the word says one colour, the ink is another.
class ColorClashSpec extends QuizSpec {
  const ColorClashSpec();

  static const List<ClashColor> palette = [
    ClashColor('RED', Color(0xFFFF5A5A)),
    ClashColor('BLUE', Color(0xFF5B9BFF)),
    ClashColor('GREEN', Color(0xFF55E07A)),
    ClashColor('YELLOW', Color(0xFFFFD84D)),
    ClashColor('PURPLE', Color(0xFFB07CFF)),
  ];

  @override
  String get id => 'color';

  @override
  String get title => 'Color Clash';

  @override
  String get intro =>
      'The word and its colour disagree. Follow the instruction, fast. Ten questions.';

  @override
  String get opening => 'Red? Blue? Good luck, human.';

  @override
  Duration timeFor(Level level) => switch (level) {
        Level.easy => const Duration(seconds: 4),
        Level.medium => const Duration(seconds: 3),
        Level.hard => const Duration(milliseconds: 2500),
      };

  @override
  double zedAccuracy(Level level) => switch (level) {
        Level.easy => 0.75,
        Level.medium => 0.85,
        Level.hard => 0.92,
      };

  @override
  QuizQuestion question({
    required int round,
    required Level level,
    required Random rng,
  }) {
    final easy = level == Level.easy;
    final hard = level == Level.hard;
    final colors = palette.sublist(0, easy ? 3 : (hard ? 5 : 4));

    final word = colors[rng.nextInt(colors.length)];
    var ink = word;
    if (rng.nextDouble() < (easy ? 0.7 : 0.9)) {
      do {
        ink = colors[rng.nextInt(colors.length)];
      } while (ink.name == word.name);
    }

    // On Hard, some rounds flip the rule: tap what the WORD says.
    final askWord = hard && round >= 3 && rng.nextDouble() < 0.3;
    final target = askWord ? word : ink;
    final options = [...colors]..shuffle(rng);
    return QuizQuestion(
      prompt: word.name,
      promptColor: ink.color,
      hint: askWord ? 'Tap what the WORD says' : 'Tap the INK colour',
      options: [for (final c in options) QuizOption(c.name)],
      answer: options.indexWhere((c) => c.name == target.name),
    );
  }
}

class _SenseValue {
  const _SenseValue(this.value, this.label);

  final double value;
  final String label;
}

/// Fractions, decimals and percents side by side: pick the biggest, or on
/// harder levels sometimes the smallest.
class NumberSenseSpec extends QuizSpec {
  const NumberSenseSpec();

  static final List<_SenseValue> _pool = _buildPool();

  static List<_SenseValue> _buildPool() {
    final out = <_SenseValue>[];
    for (final d in const [2, 3, 4, 5, 6, 8, 10]) {
      for (var n = 1; n < d; n++) {
        out.add(_SenseValue(n / d, '$n/$d'));
      }
    }
    for (var k = 5; k <= 95; k += 5) {
      out.add(_SenseValue(k / 100, (k / 100).toStringAsFixed(2)));
      out.add(_SenseValue(k / 100, '$k%'));
    }
    return out;
  }

  @override
  String get id => 'sense';

  @override
  String get title => 'Number Sense';

  @override
  String get intro =>
      'Fractions, decimals and percents. Pick the right one before the clock runs out. Ten questions.';

  @override
  String get opening => 'Fractions, decimals, percents. I see them all as one.';

  @override
  Duration timeFor(Level level) => switch (level) {
        Level.easy => const Duration(seconds: 8),
        Level.medium => const Duration(seconds: 6),
        Level.hard => const Duration(seconds: 5),
      };

  @override
  double zedAccuracy(Level level) => switch (level) {
        Level.easy => 0.7,
        Level.medium => 0.8,
        Level.hard => 0.88,
      };

  @override
  QuizQuestion question({
    required int round,
    required Level level,
    required Random rng,
  }) {
    final gap = switch (level) {
      Level.easy => 0.2,
      Level.medium => 0.1,
      Level.hard => 0.05,
    };
    final count = level == Level.hard ? 4 : 3;
    final askSmallest =
        level != Level.easy && round >= 3 && rng.nextDouble() < 0.3;

    List<_SenseValue>? picked;
    for (var attempt = 0; attempt < 300 && picked == null; attempt++) {
      final tryList = <_SenseValue>[
        for (var i = 0; i < count; i++) _pool[rng.nextInt(_pool.length)],
      ];
      final sorted = [for (final v in tryList) v.value]..sort();
      var ok = true;
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i] - sorted[i - 1] < gap - 1e-9) ok = false;
      }
      if (ok) picked = tryList;
    }
    final chosen = picked ??
        (<_SenseValue>[
          const _SenseValue(0.2, '0.20'),
          const _SenseValue(0.4, '40%'),
          const _SenseValue(0.6, '3/5'),
          const _SenseValue(0.8, '4/5'),
        ]..shuffle(rng))
            .sublist(0, count);

    final values = [for (final v in chosen) v.value];
    final target = askSmallest
        ? values.reduce((a, b) => a < b ? a : b)
        : values.reduce((a, b) => a > b ? a : b);
    return QuizQuestion(
      prompt: askSmallest ? 'SMALLEST?' : 'BIGGEST?',
      hint: 'Fractions, decimals and percents',
      options: [for (final v in chosen) QuizOption(v.label)],
      answer: chosen.indexWhere((v) => v.value == target),
    );
  }
}
