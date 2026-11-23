import 'package:beat_the_bot/core/rank_service.dart';
import 'package:beat_the_bot/core/zed_streak.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ZedStreak> makeStreak(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return ZedStreak(await SharedPreferences.getInstance());
}

void main() {
  test('the first win over Zed starts the streak at 1', () async {
    final z = await makeStreak({});
    final r = await z.onGauntletResult(DateTime(2026, 10, 10), beatZed: true);
    expect(r.increased, isTrue);
    expect(r.current, 1);
    expect(z.current(DateTime(2026, 10, 10)), 1);
    expect(z.beatToday(DateTime(2026, 10, 10)), isTrue);
  });

  test('wins on consecutive days build the streak', () async {
    final z = await makeStreak({});
    await z.onGauntletResult(DateTime(2026, 10, 10), beatZed: true);
    await z.onGauntletResult(DateTime(2026, 10, 11), beatZed: true);
    final r = await z.onGauntletResult(DateTime(2026, 10, 12), beatZed: true);
    expect(r.current, 3);
    expect(r.milestone, 3);
    expect(z.best, 3);
  });

  test('a loss does not count, and does not end the day yet', () async {
    final z = await makeStreak({});
    await z.onGauntletResult(DateTime(2026, 10, 10), beatZed: true);
    final lost = await z.onGauntletResult(DateTime(2026, 10, 11), beatZed: false);
    expect(lost.increased, isFalse);
    expect(lost.current, 1);
    // The player may replay, and a win later the same day still counts.
    final won = await z.onGauntletResult(DateTime(2026, 10, 11), beatZed: true);
    expect(won.increased, isTrue);
    expect(won.current, 2);
  });

  test('a second win on the same day does not count twice', () async {
    final z = await makeStreak({});
    await z.onGauntletResult(DateTime(2026, 10, 10), beatZed: true);
    final again = await z.onGauntletResult(DateTime(2026, 10, 10), beatZed: true);
    expect(again.increased, isFalse);
    expect(again.current, 1);
  });

  test('a streak at risk is flagged until Zed is beaten today', () async {
    final z = await makeStreak({});
    await z.onGauntletResult(DateTime(2026, 10, 10), beatZed: true);
    expect(z.atRisk(DateTime(2026, 10, 10)), isFalse);
    expect(z.atRisk(DateTime(2026, 10, 11)), isTrue);
  });

  test('one missed day with no shield ends the streak', () async {
    final z = await makeStreak({});
    await z.onGauntletResult(DateTime(2026, 10, 10), beatZed: true);
    await z.onGauntletResult(DateTime(2026, 10, 11), beatZed: true);
    // Nothing on the 12th. The player returns on the 13th.
    expect(z.current(DateTime(2026, 10, 13)), 0);
    final settle = await z.settle(DateTime(2026, 10, 13));
    expect(settle.broken, isTrue);
    expect(settle.lostLength, 2);
    expect(z.current(DateTime(2026, 10, 13)), 0);
    // It does not announce the same loss twice.
    final again = await z.settle(DateTime(2026, 10, 13));
    expect(again.broken, isFalse);
  });

  test('after a break, the next win starts again from 1 and keeps the best',
      () async {
    final z = await makeStreak({
      'zs_count': 5,
      'zs_best': 5,
      'zs_last': '2026-10-10',
    });
    final r = await z.onGauntletResult(DateTime(2026, 10, 14), beatZed: true);
    expect(r.current, 1);
    expect(r.isNewBest, isFalse);
    expect(z.best, 5);
  });

  test('a shield covers exactly one missed day', () async {
    final z = await makeStreak({
      'zs_count': 7,
      'zs_best': 7,
      'zs_last': '2026-10-10',
      'zs_shields': 1,
    });
    expect(z.current(DateTime(2026, 10, 12)), 7);
    final settle = await z.settle(DateTime(2026, 10, 12));
    expect(settle.shieldsUsed, 1);
    expect(settle.broken, isFalse);
    expect(z.shields, 0);
    final r = await z.onGauntletResult(DateTime(2026, 10, 12), beatZed: true);
    expect(r.current, 8);
    expect(r.isNewBest, isTrue);
  });

  test('one shield cannot cover two missed days', () async {
    final z = await makeStreak({
      'zs_count': 9,
      'zs_best': 9,
      'zs_last': '2026-10-10',
      'zs_shields': 1,
    });
    expect(z.current(DateTime(2026, 10, 13)), 0);
    final settle = await z.settle(DateTime(2026, 10, 13));
    expect(settle.broken, isTrue);
    expect(settle.lostLength, 9);
  });

  test('the seventh day earns a shield, and shields are capped', () async {
    final z = await makeStreak({
      'zs_count': 6,
      'zs_best': 6,
      'zs_last': '2026-10-10',
    });
    final r = await z.onGauntletResult(DateTime(2026, 10, 11), beatZed: true);
    expect(r.current, 7);
    expect(r.shieldEarned, isTrue);
    expect(r.milestone, 7);
    expect(z.shields, 1);

    final full = await makeStreak({
      'zs_count': 13,
      'zs_best': 13,
      'zs_last': '2026-10-10',
      'zs_shields': ZedStreak.maxShields,
    });
    final r2 = await full.onGauntletResult(DateTime(2026, 10, 11), beatZed: true);
    expect(r2.current, 14);
    expect(r2.shieldEarned, isFalse);
    expect(full.shields, ZedStreak.maxShields);
  });

  test('a phone clock moved back changes nothing', () async {
    final z = await makeStreak({
      'zs_count': 4,
      'zs_best': 4,
      'zs_last': '2026-10-10',
    });
    final settle = await z.settle(DateTime(2026, 10, 8));
    expect(settle.broken, isFalse);
    expect(z.current(DateTime(2026, 10, 8)), 4);
  });

  test('opening the app after a missed day queues a notice', () async {
    SharedPreferences.setMockInitialValues({
      'lastPlayed': '2026-10-10',
      'streak': 3,
      'zs_count': 5,
      'zs_best': 5,
      'zs_last': '2026-10-10',
    });
    final rank = RankService(await SharedPreferences.getInstance());
    await rank.onAppOpen(DateTime(2026, 10, 14));
    final notices = await rank.takeNotices();
    expect(notices.any((n) => n.contains('Zed Streak')), isTrue);
    expect(rank.zedStreak.current(DateTime(2026, 10, 14)), 0);
  });

  test('resetting progress also clears the Zed Streak', () async {
    SharedPreferences.setMockInitialValues({
      'zs_count': 5,
      'zs_best': 5,
      'zs_last': '2026-10-10',
      'zs_shields': 1,
    });
    final rank = RankService(await SharedPreferences.getInstance());
    await rank.resetProgress();
    expect(rank.zedStreak.current(DateTime(2026, 10, 10)), 0);
    expect(rank.zedStreak.best, 0);
    expect(rank.zedStreak.shields, 0);
  });
}
