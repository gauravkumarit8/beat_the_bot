/// What the player picks on the Home screen.
enum Difficulty { easy, medium, hard, auto }

/// What a game actually uses. "Auto" is resolved into one of these.
enum Level { easy, medium, hard }

extension LevelLabel on Level {
  String get label => name[0].toUpperCase() + name.substring(1);
}

extension DifficultyLabel on Difficulty {
  String get label => name[0].toUpperCase() + name.substring(1);
}
