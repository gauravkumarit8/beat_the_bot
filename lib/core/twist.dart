/// Zed's twist of the day: a rule that really changes Math Rush and Color
/// Clash for one day. Everyone gets the same twist, and the first win under
/// it pays a small bonus. Not used in the Daily Gauntlet or friend challenges,
/// so those stay fair and comparable.
class ZedTwist {
  const ZedTwist({
    required this.id,
    required this.title,
    required this.rule,
    this.timeFactor = 1.0,
    this.extraRounds = 0,
    this.zedAccuracyDelta = 0.0,
  });

  final String id;
  final String title;
  final String rule;

  /// Multiplies the time for each question (0.7 means 30% less time).
  final double timeFactor;

  /// Questions added to the usual ten.
  final int extraRounds;

  /// Added to Zed's chance of answering correctly (negative: Zed is weaker).
  final double zedAccuracyDelta;
}

const List<ZedTwist> zedTwists = [
  ZedTwist(
    id: 'lightning',
    title: 'Lightning',
    rule: 'Every question has 30% less time.',
    timeFactor: 0.7,
  ),
  ZedTwist(
    id: 'marathon',
    title: 'Marathon',
    rule: 'Four extra questions. Stay sharp to the end.',
    extraRounds: 4,
  ),
  ZedTwist(
    id: 'offday',
    title: "Zed's off day",
    rule: 'Zed makes more mistakes today. Do not waste it.',
    zedAccuracyDelta: -0.2,
  ),
];

/// Today's twist. Changes every day, the same for every player.
ZedTwist twistForDay(DateTime now) {
  final days =
      DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
          86400000;
  return zedTwists[days % zedTwists.length];
}
