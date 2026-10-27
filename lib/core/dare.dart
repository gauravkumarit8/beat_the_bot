/// Zed's dare of the day: beat him in one chosen game for bonus points.
class DailyDare {
  const DailyDare({
    required this.game,
    required this.title,
    required this.reward,
  });

  /// One of: reflex, memory, precision, pattern.
  final String game;
  final String title;
  final int reward;
}

const List<String> _dareGames = ['reflex', 'memory', 'precision', 'pattern'];

const Map<String, String> _dareTitles = {
  'reflex': 'Beat me at Reflex',
  'memory': 'Out-remember me in Memory',
  'precision': 'Out-aim me in Precision',
  'pattern': 'Crack my patterns',
};

/// The same dare for everyone on the same date.
DailyDare dareForDay(DateTime now) {
  final day = DateTime.utc(now.year, now.month, now.day)
      .difference(DateTime.utc(2026, 1, 1))
      .inDays;
  final game = _dareGames[day % _dareGames.length];
  return DailyDare(game: game, title: _dareTitles[game]!, reward: 20);
}
