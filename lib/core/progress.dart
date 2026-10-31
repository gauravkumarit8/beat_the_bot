import 'dart:math';

import 'rank_service.dart';

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// Each function turns a personal best into a 0..1 skill level.
double reflexSkill(int ms) => ms <= 0 ? 0 : _clamp01((450 - ms) / 250);
double memorySkill(int tiles) => _clamp01((tiles - 3) / 7);
double precisionSkill(int percent) => _clamp01((percent - 50) / 45);
double patternSkill(int score) => _clamp01(score / 700);
double quizSkill(int score) => _clamp01(score / 1300);

/// A playful "brain age" from the games you have played. Not a medical
/// measure. Returns null until at least one skill is known.
int? brainAge(List<double> skills) {
  if (skills.isEmpty) return null;
  final avg = skills.reduce((a, b) => a + b) / skills.length;
  final age = (60 - 40 * avg).round();
  return age < 20 ? 20 : (age > 60 ? 60 : age);
}

class LadderEntry {
  const LadderEntry(this.name, this.points, this.isYou);

  final String name;
  final int points;
  final bool isYou;
}

const List<String> _botNames = [
  'Nova', 'Pixel', 'Echo', 'Bolt', 'Rune', 'Axel', 'Mira', 'Tango', 'Kite',
];

/// Your weekly ladder against nine rival bots. The bots are generated on the
/// phone from the week's date, so everyone sees the same bots that week, and
/// they earn their points gradually through the week.
List<LadderEntry> buildLadder({
  required DateTime now,
  required int yourPoints,
}) {
  final start = RankService.weekStart(now);
  final seed = start.millisecondsSinceEpoch ~/ 86400000;
  final fraction = now.weekday / 7.0;
  final entries = <LadderEntry>[
    for (var i = 0; i < _botNames.length; i++)
      LadderEntry(
        _botNames[i],
        ((60 + Random(seed * 31 + i).nextInt(360)) * fraction).round(),
        false,
      ),
    LadderEntry('You', yourPoints, true),
  ];
  entries.sort((a, b) {
    final byPoints = b.points.compareTo(a.points);
    if (byPoints != 0) return byPoints;
    if (a.isYou != b.isYou) return a.isYou ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  return entries;
}

int yourPlace(List<LadderEntry> ladder) =>
    ladder.indexWhere((e) => e.isYou) + 1;
