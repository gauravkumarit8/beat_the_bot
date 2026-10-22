import 'dart:math';

/// One number-sequence question: [shown] numbers, then pick the next one.
class PatternPuzzle {
  const PatternPuzzle({
    required this.shown,
    required this.answer,
    required this.options,
    required this.rule,
  });

  final List<int> shown;
  final int answer;
  final List<int> options;
  final String rule;
}

/// Makes number puzzles offline. Level 1 is easiest, level 5 hardest.
class PatternGenerator {
  PatternGenerator([Random? rng]) : _rng = rng ?? Random();

  final Random _rng;

  PatternPuzzle generate(int level) {
    final lv = level < 1 ? 1 : (level > 5 ? 5 : level);
    List<int> seq;
    String rule;

    switch (lv) {
      case 1:
        final d = 2 + _rng.nextInt(8);
        final s = 1 + _rng.nextInt(20);
        seq = List<int>.generate(6, (i) => s + d * i);
        rule = 'Add $d each time';
      case 2:
        final m = 2 + _rng.nextInt(2);
        final s = 1 + _rng.nextInt(3);
        seq = [s];
        for (var i = 1; i < 6; i++) {
          seq.add(seq.last * m);
        }
        rule = 'Multiply by $m each time';
      case 3:
        final a = 1 + _rng.nextInt(5);
        final b = a + 1 + _rng.nextInt(5);
        seq = [1 + _rng.nextInt(10)];
        for (var i = 0; i < 6; i++) {
          seq.add(seq.last + (i.isEven ? a : b));
        }
        rule = 'Add $a, then $b, and repeat';
      case 4:
        final k = 1 + _rng.nextInt(3);
        final c = _rng.nextInt(5);
        seq = List<int>.generate(6, (i) => (k + i) * (k + i) + c);
        rule = c == 0 ? 'Square numbers' : 'Square numbers, plus $c';
      default:
        final a = 1 + _rng.nextInt(4);
        final b = 1 + _rng.nextInt(4);
        seq = [a, b];
        while (seq.length < 7) {
          seq.add(seq[seq.length - 1] + seq[seq.length - 2]);
        }
        rule = 'Each number is the sum of the previous two';
    }

    final answer = seq.last;
    final shown = seq.sublist(0, seq.length - 1);
    return PatternPuzzle(
      shown: shown,
      answer: answer,
      options: _options(answer),
      rule: rule,
    );
  }

  List<int> _options(int answer) {
    final wrong = <int>{};
    while (wrong.length < 3) {
      final delta = (1 + _rng.nextInt(6)) * (_rng.nextBool() ? 1 : -1);
      final v = answer + delta;
      if (v > 0 && v != answer) wrong.add(v);
    }
    return [answer, ...wrong]..shuffle(_rng);
  }
}
