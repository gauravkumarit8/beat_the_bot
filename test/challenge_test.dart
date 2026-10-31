import 'package:beat_the_bot/core/challenge.dart';
import 'package:beat_the_bot/core/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sample = Challenge(
    game: 'memory',
    level: Level.hard,
    seed: 123456,
    score: 7,
  );

  test('a code survives a round trip', () {
    expect(sample.code, startsWith('BTB-MH-2N9C-7-'));
    final back = Challenge.parse(sample.code)!;
    expect(back.game, 'memory');
    expect(back.level, Level.hard);
    expect(back.seed, 123456);
    expect(back.score, 7);
  });

  test('every game and level works', () {
    for (final game in ['memory', 'precision', 'pattern']) {
      for (final level in Level.values) {
        final c = Challenge(game: game, level: level, seed: 99, score: 640);
        final back = Challenge.parse(c.code)!;
        expect(back.game, game);
        expect(back.level, level);
        expect(back.score, 640);
      }
    }
  });

  test('the new quiz games have challenge codes too', () {
    for (final game in ['math', 'color']) {
      final c = Challenge(game: game, level: Level.medium, seed: 4242, score: 910);
      final back = Challenge.parse(c.code)!;
      expect(back.game, game);
      expect(back.score, 910);
    }
    const math =
        Challenge(game: 'math', level: Level.hard, seed: 1, score: 1200);
    expect(math.shareText, contains('Math Rush'));
  });

  test('lowercase codes and whole pasted messages are accepted', () {
    const c = Challenge(
        game: 'pattern', level: Level.easy, seed: 99, score: 640);
    expect(Challenge.parse(c.code.toLowerCase())!.seed, 99);
    expect(Challenge.parse('Hey! ${c.shareText} Good luck')!.score, 640);
  });

  test('a mistyped or altered code is rejected', () {
    final code = sample.code;
    final last = code[code.length - 1];
    final wrongLast =
        code.substring(0, code.length - 1) + (last == 'A' ? 'B' : 'A');
    expect(Challenge.parse(wrongLast), isNull);
    expect(Challenge.parse(code.replaceFirst('-7-', '-8-')), isNull);
    expect(Challenge.parse('hello'), isNull);
    expect(Challenge.parse('BTB-XX-1-1-1'), isNull);
  });

  test('labels and share text read well', () {
    expect(sample.scoreLabel(7), '7 tiles');
    expect(sample.shareText, contains('7 tiles'));
    expect(sample.shareText, contains('Memory (Hard)'));
    expect(sample.shareText, contains(sample.code));
    const precision =
        Challenge(game: 'precision', level: Level.medium, seed: 1, score: 88);
    expect(precision.scoreLabel(88), '88%');
  });
}
