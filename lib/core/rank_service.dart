// lib/core/rank_service.dart
// Offline rank, streak and daily-twist logic for Beat the Bot.
// Needs: shared_preferences in pubspec.yaml. No server, no network.

import 'package:shared_preferences/shared_preferences.dart';

import 'achievements.dart';
import 'dare.dart';
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

/// What the player earned for finishing the Daily Gauntlet.
class GauntletReward {
  const GauntletReward({
    required this.firstToday,
    required this.points,
    required this.rankUp,
  });

  /// Rewards only count for the first Gauntlet each day.
  final bool firstToday;
  final int points;
  final Rank? rankUp;
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

  // ---- Settings -----------------------------------------------------------

  bool get vibrationOn => _prefs.getBool('vibration') ?? true;
  Future<void> setVibration(bool on) => _prefs.setBool('vibration', on);

  bool get onboarded => _prefs.getBool('onboarded') ?? false;
  Future<void> setOnboarded() => _prefs.setBool('onboarded', true);

  /// Erases rank, streak, bests and learned difficulty. Settings stay.
  Future<void> resetProgress() async {
    const keep = {'adsRemoved', 'vibration', 'difficulty', 'onboarded'};
    for (final key in _prefs.getKeys().toList()) {
      if (!keep.contains(key)) await _prefs.remove(key);
    }
  }

  // ---- Rivalry: record, revenge, dare, notices ------------------------------

  static const int revengeBonus = 10;

  /// From this many wins in a row, every extra win pays a bonus.
  static const int hotStreakFrom = 4;
  static const int hotStreakBonus = 5;

  /// Set by a rewarded ad. Makes Zed weaker for the next match only.
  bool get zedWeakened => _prefs.getBool('zedWeak') ?? false;
  Future<void> setZedWeakened(bool on) => _prefs.setBool('zedWeak', on);

  bool gauntletDoubled(DateTime now) =>
      _prefs.getString('doubleDay') == _key(now);

  /// Rewarded ad on the Gauntlet result: pay the day's reward a second time.
  Future<Rank?> doubleGauntletReward(DateTime now, int points) async {
    if (gauntletDoubled(now) || points <= 0) return null;
    await _prefs.setString('doubleDay', _key(now));
    return _add(points);
  }

  int get totalLosses => _prefs.getInt('totalLosses') ?? 0;
  int get winStreak => _prefs.getInt('winStreak') ?? 0;
  int get lossStreak => _prefs.getInt('lossStreak') ?? 0;

  /// True after a loss. The next win against Zed pays a revenge bonus.
  bool get revengeReady => _prefs.getBool('revenge') ?? false;

  bool dareDone(DateTime now) => _prefs.getString('dareDay') == _key(now);

  Future<void> _queueNotice(String message) async {
    final list = _prefs.getStringList('notices') ?? <String>[];
    await _prefs.setStringList('notices', [...list, message]);
  }

  /// Short messages (revenge, dare) to show once, then forget.
  Future<List<String>> takeNotices() async {
    final list = _prefs.getStringList('notices') ?? <String>[];
    if (list.isNotEmpty) await _prefs.remove('notices');
    return list;
  }

  // ---- Achievements -------------------------------------------------------

  int get totalWins => _prefs.getInt('totalWins') ?? 0;
  int get hardWins => _prefs.getInt('hardWins') ?? 0;
  int get perfectGauntlets => _prefs.getInt('perfectGauntlets') ?? 0;
  int get bestStreak => _prefs.getInt('bestStreak') ?? 0;
  int get highestRankIndex => _prefs.getInt('highestRank') ?? 0;

  Future<void> _setStreak(int value) async {
    await _prefs.setInt('streak', value);
    if (value > bestStreak) await _prefs.setInt('bestStreak', value);
  }

  Future<void> _noteHighestRank() async {
    if (rank.index > highestRankIndex) {
      await _prefs.setInt('highestRank', rank.index);
    }
  }

  Set<String> get unlockedAchievements =>
      (_prefs.getStringList('achievements') ?? const <String>[]).toSet();

  /// Unlocks any badge whose goal is now met. Returns the newly unlocked ones.
  Future<List<Achievement>> checkAchievements() async {
    final unlocked = unlockedAchievements;
    final fresh = [
      for (final a in allAchievements)
        if (!unlocked.contains(a.id) && a.isMet(this)) a,
    ];
    if (fresh.isNotEmpty) {
      await _prefs.setStringList(
        'achievements',
        [...unlocked, for (final a in fresh) a.id],
      );
    }
    return fresh;
  }

  // ---- Progress: weekly points, history, reflex best ------------------------

  /// The Monday that starts the week containing [now].
  static DateTime weekStart(DateTime now) =>
      _dateOnly(now).subtract(Duration(days: now.weekday - 1));

  /// "yyyy-MM-dd" key for a day, used by the progress screen.
  static String dayKey(DateTime d) => _key(d);

  /// Rank points earned since Monday. Resets by itself every week.
  int weeklyPoints(DateTime now) {
    if (_prefs.getString('weekKey') != _key(weekStart(now))) return 0;
    return _prefs.getInt('weekRp') ?? 0;
  }

  Future<void> _addWeekly(int points, DateTime now) async {
    final key = _key(weekStart(now));
    final current = _prefs.getString('weekKey') == key
        ? (_prefs.getInt('weekRp') ?? 0)
        : 0;
    await _prefs.setString('weekKey', key);
    await _prefs.setInt('weekRp', current + points);
  }

  /// Best Gauntlet score for each recent day (up to 30 days), by day key.
  Map<String, int> gauntletHistory() {
    final out = <String, int>{};
    for (final e in _prefs.getStringList('gauntletHistory') ?? const <String>[]) {
      final i = e.indexOf(':');
      if (i < 0) continue;
      final v = int.tryParse(e.substring(i + 1));
      if (v != null) out[e.substring(0, i)] = v;
    }
    return out;
  }

  Future<void> _saveGauntletScore(String key, int score) async {
    final history = gauntletHistory();
    if (score > (history[key] ?? 0)) history[key] = score;
    final keys = history.keys.toList()..sort();
    final kept = keys.length > 30 ? keys.sublist(keys.length - 30) : keys;
    await _prefs.setStringList(
      'gauntletHistory',
      [for (final k in kept) '$k:${history[k]}'],
    );
  }

  /// Fastest valid reaction time in milliseconds, or 0 if none yet.
  int get reflexBestMs => _prefs.getInt('reflexBestMs') ?? 0;

  Future<void> noteReflexTime(int ms) async {
    if (ms <= 0) return;
    final best = reflexBestMs;
    if (best == 0 || ms < best) await _prefs.setInt('reflexBestMs', ms);
  }

  // ---- Daily Gauntlet -----------------------------------------------------

  int get gauntletBest => _prefs.getInt('gauntletBest') ?? 0;

  /// Today's best Gauntlet score, or null if it has not been played today.
  int? gauntletTodayScore(DateTime now) {
    if (_prefs.getString('gauntletDay') != _key(now)) return null;
    return _prefs.getInt('gauntletTodayScore');
  }

  static const int gauntletBonus = 20;

  Future<GauntletReward> onGauntletDone(
      DateTime now, int wins, int score) async {
    final key = _key(now);
    await _saveGauntletScore(key, score);
    if (wins >= 4) {
      await _prefs.setInt('perfectGauntlets', perfectGauntlets + 1);
    }
    final first = _prefs.getString('gauntletDay') != key;
    if (score > gauntletBest) await _prefs.setInt('gauntletBest', score);

    final previous = first ? 0 : (_prefs.getInt('gauntletTodayScore') ?? 0);
    await _prefs.setString('gauntletDay', key);
    await _prefs.setInt('gauntletTodayScore', score > previous ? score : previous);

    if (!first) {
      return const GauntletReward(firstToday: false, points: 0, rankUp: null);
    }
    final before = rank;
    final warmup = _warmupDay == key ? 0 : pointsPerWarmup;
    final points = warmup + wins * pointsPerWin + gauntletBonus;
    await _prefs.setString('warmupDay', key);
    await _prefs.setInt('rp', rankPoints + points);
    await _addWeekly(points, now);
    await _noteHighestRank();
    return GauntletReward(
      firstToday: true,
      points: points,
      rankUp: rank.index > before.index ? rank : null,
    );
  }

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

  /// Call after every finished match. Teaches Auto difficulty, keeps the win
  /// and loss counts, and pays the revenge bonus and Zed's daily dare.
  Future<void> recordResult(String game, Level played, bool won,
      {DateTime? now}) async {
    final old = _autoLevel(game);
    final anchor = played.index.toDouble();
    var next = won
        ? (old > anchor ? old : anchor) + 0.3
        : (old < anchor ? old : anchor) - 0.3;
    if (next < 0) next = 0;
    if (next > 2) next = 2;
    await _prefs.setDouble('auto_$game', next);

    if (!won) {
      await _prefs.setInt('totalLosses', totalLosses + 1);
      await _prefs.setInt('lossStreak', lossStreak + 1);
      await _prefs.setInt('winStreak', 0);
      await _prefs.setBool('revenge', true);
      return;
    }

    await _prefs.setInt('totalWins', totalWins + 1);
    if (played == Level.hard) {
      await _prefs.setInt('hardWins', hardWins + 1);
    }
    await _prefs.setInt('winStreak', winStreak + 1);
    if (winStreak >= hotStreakFrom) {
      await _add(hotStreakBonus);
      await _queueNotice('Hot streak x$winStreak! +$hotStreakBonus RP');
    }
    await _prefs.setInt('lossStreak', 0);

    if (revengeReady) {
      await _prefs.setBool('revenge', false);
      await _add(revengeBonus);
      await _queueNotice('Revenge! +$revengeBonus RP');
    }

    final today = now ?? DateTime.now();
    final dare = dareForDay(today);
    if (dare.game == game && !dareDone(today)) {
      await _prefs.setString('dareDay', _key(today));
      await _add(dare.reward);
      await _queueNotice('Zed\u2019s dare done! +${dare.reward} RP');
    }
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
      await _setStreak(1);
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
    await _setStreak(keepStreak ? streak + 1 : 1);
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
    await _addWeekly(points, DateTime.now());
    await _noteHighestRank();
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
