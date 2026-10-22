// lib/core/rank_service.dart
// Offline rank, streak and daily-twist logic for Beat the Bot.
// Needs: shared_preferences in pubspec.yaml. No server, no network.

import 'package:shared_preferences/shared_preferences.dart';

import 'difficulty.dart';

enum Rank { rookie, sharp, elite, master, legend }

/// Minimum rank points (RP) needed for each rank.
const Map<Rank, int> rankThreshold = {
  Rank.rookie: 0,
  Rank.sharp: 100,
  Rank.elite: 400,
  Rank.master: 900,
  Rank.legend: 1800,
};

Rank rankForPoints(int rp) {
  Rank result = Rank.rookie;
  for (final r in Rank.values) {
    if (rp >= rankThreshold[r]!) result = r;
  }
  return result;
}

/// What happened when the player came back; the UI uses this for messages.
class ReturnResult {
  final int missedDays;
  final int pointsLost;
  final bool usedFreeze;
  final Rank before;
  final Rank after;
  const ReturnResult({
    required this.missedDays,
    required this.pointsLost,
    required this.usedFreeze,
    required this.before,
    required this.after,
  });

  bool get rankDropped => after.index < before.index;
}

class RankService {
  static const int pointsPerLevel = 10;
  static const int pointsPerWarmup = 15;
  static const int pointsPerWin = 5;
  static const int lossPerMissedDay = 20;

  final SharedPreferences _prefs;
  RankService(this._prefs);

  int get rankPoints => _prefs.getInt('rp') ?? 0;
  int get streak => _prefs.getInt('streak') ?? 0;
  int get freezes => _prefs.getInt('freezes') ?? 0;
  Rank get rank => rankForPoints(rankPoints);

  /// Longest memory sequence the player has ever cleared.
  int get memoryBest => _prefs.getInt('memoryBest') ?? 0;
  Future<void> setMemoryBest(int tiles) => _prefs.setInt('memoryBest', tiles);

  /// Best average accuracy (percent) in Precision mode.
  int get precisionBest => _prefs.getInt('precisionBest') ?? 0;
  Future<void> setPrecisionBest(int percent) =>
      _prefs.setInt('precisionBest', percent);

  /// Best total score in Pattern mode.
  int get patternBest => _prefs.getInt('patternBest') ?? 0;
  Future<void> setPatternBest(int score) =>
      _prefs.setInt('patternBest', score);

  // ---- Difficulty ---------------------------------------------------------

  /// The player's choice. Defaults to Auto.
  Difficulty get difficulty {
    final saved = _prefs.getString('difficulty');
    return Difficulty.values.firstWhere(
      (d) => d.name == saved,
      orElse: () => Difficulty.auto,
    );
  }

  Future<void> setDifficulty(Difficulty d) =>
      _prefs.setString('difficulty', d.name);

  /// 0 = easy, 1 = medium, 2 = hard. Moves with wins and losses per game.
  double _autoLevel(String game) => _prefs.getDouble('auto_$game') ?? 1.0;

  /// The level Zed plays at for [game], honouring the player's choice.
  Level levelFor(String game) {
    switch (difficulty) {
      case Difficulty.easy:
        return Level.easy;
      case Difficulty.medium:
        return Level.medium;
      case Difficulty.hard:
        return Level.hard;
      case Difficulty.auto:
        final v = _autoLevel(game);
        if (v < 0.67) return Level.easy;
        if (v < 1.33) return Level.medium;
        return Level.hard;
    }
  }

  /// Call after every finished match so Auto learns from the player's record.
  /// The change is anchored to the level that was actually played.
  Future<void> recordResult(String game, Level played, bool won) async {
    final old = _autoLevel(game);
    final anchor = played.index.toDouble();
    var next = won
        ? (old > anchor ? old : anchor) + 0.3
        : (old < anchor ? old : anchor) - 0.3;
    if (next < 0) next = 0;
    if (next > 2) next = 2;
    await _prefs.setDouble('auto_$game', next);
  }

  String? get _lastPlayed => _prefs.getString('lastPlayed');
  String? get _warmupDay => _prefs.getString('warmupDay');

  // ---- Dates -------------------------------------------------------------

  static DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  static String _key(DateTime d) {
    final x = _dateOnly(d);
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parse(String s) {
    final p = s.split('-').map(int.parse).toList();
    return DateTime.utc(p[0], p[1], p[2]);
  }

  // ---- Call this once each time the app opens -----------------------------

  /// Returns null on first launch or when nothing changed today.
  Future<ReturnResult?> onAppOpen(DateTime now) async {
    final today = _dateOnly(now);
    final last = _lastPlayed;
    if (last == null) {
      await _prefs.setString('lastPlayed', _key(today));
      await _prefs.setInt('streak', 1);
      return null;
    }

    final gap = today.difference(_parse(last)).inDays; // 1 = played yesterday
    if (gap <= 0) return null; // same day (or clock moved back): do nothing

    final missed = gap - 1;
    final before = rank;
    var lost = 0;
    var usedFreeze = false;

    if (missed >= 2) {
      if (freezes > 0) {
        usedFreeze = true;
        await _prefs.setInt('freezes', freezes - 1);
      } else {
        lost = missed * lossPerMissedDay;
        // Never drop more than one rank per return, and never below 0.
        final floor = before.index == 0
            ? 0
            : rankThreshold[Rank.values[before.index - 1]]!;
        final reduced = rankPoints - lost;
        final newPoints = reduced < floor ? floor : reduced;
        lost = rankPoints - newPoints;
        await _prefs.setInt('rp', newPoints);
      }
    }

    // Streak: continues if played yesterday, or a freeze covered the gap.
    final keepStreak = missed == 0 || usedFreeze || missed == 1;
    await _prefs.setInt('streak', keepStreak ? streak + 1 : 1);
    await _prefs.setString('lastPlayed', _key(today));

    return ReturnResult(
      missedDays: missed,
      pointsLost: lost,
      usedFreeze: usedFreeze,
      before: before,
      after: rank,
    );
  }

  // ---- Awarding points ---------------------------------------------------

  /// Returns the new rank if the player just ranked up, otherwise null.
  Future<Rank?> _add(int points) async {
    final before = rank;
    await _prefs.setInt('rp', rankPoints + points);
    return rank.index > before.index ? rank : null;
  }

  Future<Rank?> onLevelPassed() => _add(pointsPerLevel);
  Future<Rank?> onWinAgainstZed() => _add(pointsPerWin);

  /// Warm-up points count once per day.
  Future<Rank?> onWarmupDone(DateTime now) async {
    final key = _key(now);
    if (_warmupDay == key) return null;
    await _prefs.setString('warmupDay', key);
    return _add(pointsPerWarmup);
  }

  Future<void> addFreeze() => _prefs.setInt('freezes', freezes + 1);

  /// For the optional "watch ad to restore rank" button.
  Future<void> restoreRank(Rank to) async {
    if (rankPoints < rankThreshold[to]!) {
      await _prefs.setInt('rp', rankThreshold[to]!);
    }
  }
}

// ---- Daily twist: same for everyone on the same date, no server needed ------

class DailyTwist {
  final String title;
  final String detail;
  const DailyTwist(this.title, this.detail);

  static const List<DailyTwist> _all = [
    DailyTwist('Speed mode', 'Zed reacts faster, but memory rounds are longer.'),
    DailyTwist('Memory day', 'Sequences are 2 tiles longer. Zed forgets more.'),
    DailyTwist('Precision day', 'Smaller targets, no time pressure.'),
    DailyTwist('Pattern day', 'New patterns every round. Zed is tricky.'),
    DailyTwist('Double or nothing', 'Win a round to double its points.'),
    DailyTwist('Mirror mode', 'Controls are flipped. Stay calm.'),
    DailyTwist('Marathon', 'Eight short rounds, one combined score.'),
  ];

  static DailyTwist forDate(DateTime d) {
    final days = DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(2026, 1, 1))
        .inDays;
    return _all[days % _all.length];
  }

  /// Seed for random generators so every player gets the same Gauntlet today.
  static int seedForDate(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
}
