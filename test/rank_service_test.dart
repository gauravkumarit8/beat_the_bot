import 'package:beat_the_bot/core/rank_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<RankService> makeService(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return RankService(await SharedPreferences.getInstance());
}

void main() {
  test('first launch starts a streak and returns nothing', () async {
    final s = await makeService({});
    final result = await s.onAppOpen(DateTime(2026, 10, 21));
    expect(result, isNull);
    expect(s.streak, 1);
  });

  test('one missed day costs nothing', () async {
    final s = await makeService({'rp': 450, 'lastPlayed': '2026-10-10', 'streak': 5});
    final result = await s.onAppOpen(DateTime(2026, 10, 12));
    expect(result!.pointsLost, 0);
    expect(s.rankPoints, 450);
  });

  test('several missed days drop points and one rank', () async {
    final s = await makeService({'rp': 450, 'lastPlayed': '2026-10-10', 'streak': 5});
    final result = await s.onAppOpen(DateTime(2026, 10, 15));
    expect(result!.missedDays, 4);
    expect(s.rankPoints, 370);
    expect(result.rankDropped, isTrue);
    expect(s.rank, Rank.sharp);
    expect(s.streak, 1);
  });

  test('a long absence never drops more than one rank', () async {
    final s = await makeService({'rp': 450, 'lastPlayed': '2026-09-01', 'streak': 5});
    await s.onAppOpen(DateTime(2026, 10, 21));
    expect(s.rank, Rank.sharp);
    expect(s.rankPoints, rankThreshold[Rank.sharp]);
  });

  test('a streak freeze protects points and is used up', () async {
    final s = await makeService(
        {'rp': 450, 'lastPlayed': '2026-10-10', 'streak': 5, 'freezes': 1});
    final result = await s.onAppOpen(DateTime(2026, 10, 15));
    expect(result!.usedFreeze, isTrue);
    expect(s.rankPoints, 450);
    expect(s.freezes, 0);
    expect(s.streak, 6);
  });

  test('warm-up points are only awarded once per day', () async {
    final s = await makeService({});
    final day = DateTime(2026, 10, 21);
    await s.onWarmupDone(day);
    await s.onWarmupDone(day);
    expect(s.rankPoints, RankService.pointsPerWarmup);
  });

  test('memory best starts at zero and can be saved', () async {
    final s = await makeService({});
    expect(s.memoryBest, 0);
    await s.setMemoryBest(7);
    expect(s.memoryBest, 7);
  });

  test('precision best starts at zero and can be saved', () async {
    final s = await makeService({});
    expect(s.precisionBest, 0);
    await s.setPrecisionBest(88);
    expect(s.precisionBest, 88);
  });

  test('daily twist is the same for the same date', () {
    final a = DailyTwist.forDate(DateTime(2026, 10, 21, 8));
    final b = DailyTwist.forDate(DateTime(2026, 10, 21, 22));
    expect(a.title, b.title);
  });
}
