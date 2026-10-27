import 'rank_service.dart';

enum ZedMood { neutral, smug, annoyed, shocked, sad }

class ZedLine {
  const ZedLine(this.text, this.mood);

  final String text;
  final ZedMood mood;
}

/// What Zed says on the Home screen. It reacts to your record, so he feels
/// like a rival who is paying attention.
ZedLine zedHomeLine({
  required RankService rank,
  required DateTime now,
  required int missedDays,
}) {
  if (missedDays >= 2) {
    return ZedLine(
        '$missedDays days away? I almost forgot you existed.', ZedMood.smug);
  }
  if (rank.lossStreak >= 3) {
    return ZedLine(
        "That's ${rank.lossStreak} in a row for me. Want to stop me?",
        ZedMood.smug);
  }
  if (rank.winStreak >= 3) {
    return ZedLine(
        '${rank.winStreak} wins in a row? Now I am angry.', ZedMood.annoyed);
  }
  if (rank.revengeReady) {
    return const ZedLine(
        'You owe me a rematch. A revenge bonus is waiting.', ZedMood.smug);
  }
  if (rank.totalWins + rank.totalLosses == 0) {
    return const ZedLine(
        "Pick a game. I'll pick your weakness.", ZedMood.neutral);
  }
  if (rank.rank.index >= Rank.elite.index) {
    return const ZedLine(
        'Elite? Someone has been practising behind my back.', ZedMood.shocked);
  }
  const lines = [
    ZedLine('Back for more? Brave.', ZedMood.smug),
    ZedLine('I have been warming up. Have you?', ZedMood.neutral),
    ZedLine('Your streak is cute. Let me ruin it.', ZedMood.smug),
    ZedLine('Same time, same loss?', ZedMood.smug),
    ZedLine('Your rank is showing. It is not impressive.', ZedMood.smug),
    ZedLine('Go on, pick the game you are worst at.', ZedMood.neutral),
    ZedLine('I trained all night. You napped. Obviously.', ZedMood.smug),
    ZedLine('Today I am feeling generous. That was a joke.', ZedMood.neutral),
  ];
  return lines[now.day % lines.length];
}
