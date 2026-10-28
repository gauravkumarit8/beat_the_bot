import 'difficulty.dart';

/// A score to beat, shared as a short code. It carries the game, the level and
/// the seed, so a friend plays exactly the same tiles, targets or puzzles.
/// Everything works offline: the code is the whole "server".
class Challenge {
  const Challenge({
    required this.game,
    required this.level,
    required this.seed,
    required this.score,
  });

  /// One of: memory, precision, pattern.
  final String game;
  final Level level;
  final int seed;
  final int score;

  static const Map<String, String> _gameChars = {
    'memory': 'M',
    'precision': 'P',
    'pattern': 'T',
  };

  static const Map<Level, String> _levelChars = {
    Level.easy: 'E',
    Level.medium: 'M',
    Level.hard: 'H',
  };

  static final RegExp _pattern =
      RegExp(r'BTB-([MPT])([EMH])-([0-9A-Z]+)-(\d{1,4})-([0-9A-Z])');

  /// Example: BTB-MH-1K9X2-7-Q
  String get code {
    final body = _body(_gameChars[game]!, _levelChars[level]!,
        seed.toRadixString(36).toUpperCase(), '$score');
    return 'BTB-${body.replaceFirst('|', '-')}-${_check(body)}';
  }

  // Internal layout: "<game><level>|<seed>-<score>", used for the check letter.
  static String _body(String g, String l, String seed, String score) =>
      '$g$l|$seed-$score';

  static String _check(String body) {
    var sum = 0;
    for (final r in body.runes) {
      sum = (sum * 31 + r) % 36;
    }
    return sum.toRadixString(36).toUpperCase();
  }

  /// Finds a code inside any text, so a whole pasted message works.
  /// Returns null if there is no code or its check letter is wrong.
  static Challenge? parse(String input) {
    final m = _pattern.firstMatch(input.toUpperCase());
    if (m == null) return null;
    final seed = int.tryParse(m.group(3)!, radix: 36);
    final score = int.tryParse(m.group(4)!);
    if (seed == null || score == null) return null;
    final body = _body(m.group(1)!, m.group(2)!, m.group(3)!, m.group(4)!);
    if (_check(body) != m.group(5)) return null;
    final game = _gameChars.entries.firstWhere((e) => e.value == m.group(1)).key;
    final level =
        _levelChars.entries.firstWhere((e) => e.value == m.group(2)).key;
    return Challenge(game: game, level: level, seed: seed, score: score);
  }

  String get gameTitle => switch (game) {
        'memory' => 'Memory',
        'precision' => 'Precision',
        _ => 'Pattern',
      };

  String scoreLabel(int value) => switch (game) {
        'memory' => '$value tiles',
        'precision' => '$value%',
        _ => '$value pts',
      };

  String get shareText =>
      'Can you beat my ${scoreLabel(score)} in $gameTitle (${level.label}) '
      'on Beat the Bot? Tap "Enter challenge code" on the home screen and '
      'paste: $code';
}
