import 'package:shared_preferences/shared_preferences.dart';

/// What happened to the Zed Streak when the player came back to the app.
class ZedStreakSettle {
  const ZedStreakSettle({
    this.broken = false,
    this.lostLength = 0,
    this.shieldsUsed = 0,
  });

  /// True when a missed day ended the streak.
  final bool broken;

  /// How many days the streak had before it ended.
  final int lostLength;

  /// Shields spent to cover missed days.
  final int shieldsUsed;

  static const ZedStreakSettle none = ZedStreakSettle();
}

/// What happened to the Zed Streak when a Daily Gauntlet finished.
class ZedStreakResult {
  const ZedStreakResult({
    required this.current,
    required this.best,
    required this.increased,
    required this.shieldEarned,
    required this.milestone,
    required this.isNewBest,
    required this.attemptsLeft,
    required this.limitHit,
  });

  /// Counting runs still left today (see [ZedStreak.maxAttempts]).
  final int attemptsLeft;

  /// True when the player beat Zed, but too late in the day's runs to count.
  final bool limitHit;

  /// The streak after this Gauntlet.
  final int current;
  final int best;

  /// True when this Gauntlet added a day. False for a loss, or for a second
  /// win on a day that already counted.
  final bool increased;

  final bool shieldEarned;

  /// Set when this day reached a milestone such as 7 or 30.
  final int? milestone;

  /// True when this day beat the old personal best.
  final bool isNewBest;
}

/// The hard streak: beat Zed in the Daily Gauntlet once every day.
///
/// There is no grace day. A calendar day without a win ends the streak and
/// sends it back to zero. The only protection is a shield, earned by playing:
/// one for every seventh day, with at most [maxShields] saved up. A shield
/// covers one missed day. Everything is stored on the phone.
///
/// A Gauntlet can be replayed on the same day, but the puzzles are the same
/// all day, so only the first [maxAttempts] runs of a day can count. A loss
/// followed by a win on the second run still counts. Only a day that ends
/// without a counting win breaks the streak.
class ZedStreak {
  ZedStreak(this._prefs);

  final SharedPreferences _prefs;

  static const int shieldEvery = 7;
  static const int maxShields = 2;

  /// Runs per day that can add to the streak. Later runs are just for fun.
  static const int maxAttempts = 2;
  static const List<int> milestones = [3, 7, 14, 30, 60, 100, 365];

  static const String _kCount = 'zs_count';
  static const String _kBest = 'zs_best';
  static const String _kLast = 'zs_last';
  static const String _kShields = 'zs_shields';
  static const String _kTryDay = 'zs_tryDay';
  static const String _kTries = 'zs_tries';

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

  /// "1 day" or "12 days".
  static String daysLabel(int n) => n == 1 ? '1 day' : '$n days';

  int get _count => _prefs.getInt(_kCount) ?? 0;
  String? get _last => _prefs.getString(_kLast);

  /// The longest streak the player has ever reached.
  int get best => _prefs.getInt(_kBest) ?? 0;

  /// Shields saved up.
  int get shields => _prefs.getInt(_kShields) ?? 0;

  /// The streak as the player should see it today. It does not change
  /// anything. A streak that a missed day has already ended shows as 0.
  int current(DateTime now) {
    final last = _last;
    final count = _count;
    if (last == null || count <= 0) return 0;
    final gap = _dateOnly(now).difference(_parse(last)).inDays;
    if (gap <= 1) return count;
    final missed = gap - 1;
    return missed <= shields ? count : 0;
  }

  /// Counting runs the player has used today.
  int attemptsUsed(DateTime now) =>
      _prefs.getString(_kTryDay) == _key(now) ? (_prefs.getInt(_kTries) ?? 0) : 0;

  /// Counting runs the player still has today.
  int attemptsLeft(DateTime now) {
    final left = maxAttempts - attemptsUsed(now);
    return left < 0 ? 0 : left;
  }

  /// True when Zed has already been beaten today.
  bool beatToday(DateTime now) => _count > 0 && _last == _key(now);

  /// True when the player has a streak but still has to win today to keep it.
  bool atRisk(DateTime now) => current(now) > 0 && !beatToday(now);

  /// Call when the app opens, and before recording a result. It spends
  /// shields on missed days, or ends the streak when there are not enough.
  /// Calling it again on the same day changes nothing.
  Future<ZedStreakSettle> settle(DateTime now) async {
    final last = _last;
    final count = _count;
    if (last == null || count <= 0) return ZedStreakSettle.none;

    final today = _dateOnly(now);
    final gap = today.difference(_parse(last)).inDays;
    // Same day, yesterday, or the phone's clock moved back: nothing to do.
    if (gap <= 1) return ZedStreakSettle.none;

    final missed = gap - 1;
    if (missed <= shields) {
      await _prefs.setInt(_kShields, shields - missed);
      // The missed days are covered, so the chain continues from yesterday.
      await _prefs.setString(
          _kLast, _key(today.subtract(const Duration(days: 1))));
      return ZedStreakSettle(shieldsUsed: missed);
    }

    await _prefs.setInt(_kCount, 0);
    return ZedStreakSettle(broken: true, lostLength: count);
  }

  /// Call when a Daily Gauntlet finishes. [beatZed] is true when the player
  /// won enough games to beat Zed.
  Future<ZedStreakResult> onGauntletResult(
    DateTime now, {
    required bool beatZed,
  }) async {
    await settle(now);

    final key = _key(now);
    final count = _count;
    final alreadyCounted = count > 0 && _last == key;

    // Every finished run uses one of today's counting runs.
    final used = attemptsUsed(now) + 1;
    await _prefs.setString(_kTryDay, key);
    await _prefs.setInt(_kTries, used);
    final left = attemptsLeft(now);
    final tooLate = used > maxAttempts;

    if (!beatZed || alreadyCounted || tooLate) {
      return ZedStreakResult(
        current: count,
        best: best,
        increased: false,
        shieldEarned: false,
        milestone: null,
        isNewBest: false,
        attemptsLeft: left,
        limitHit: beatZed && !alreadyCounted && tooLate,
      );
    }

    final next = count + 1;
    final oldBest = best;
    await _prefs.setInt(_kCount, next);
    await _prefs.setString(_kLast, key);
    if (next > oldBest) await _prefs.setInt(_kBest, next);

    var earned = false;
    if (next % shieldEvery == 0 && shields < maxShields) {
      await _prefs.setInt(_kShields, shields + 1);
      earned = true;
    }

    return ZedStreakResult(
      current: next,
      best: next > oldBest ? next : oldBest,
      increased: true,
      shieldEarned: earned,
      milestone: milestones.contains(next) ? next : null,
      isNewBest: oldBest > 0 && next > oldBest,
      attemptsLeft: left,
      limitHit: false,
    );
  }
}
