/// What one game hands back to the Daily Gauntlet when it finishes.
class GameResult {
  const GameResult({
    required this.game,
    required this.won,
    required this.score,
  });

  final String game;
  final bool won;

  /// 0 to 250 for each game, so the Gauntlet total is out of 1000.
  final int score;
}
