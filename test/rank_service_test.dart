import 'package:beat_the_bot/core/difficulty.dart';
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

  test('pattern best starts at zero and can be saved', () async {
    final s = await makeService({});
    expect(s.patternBest, 0);
    await s.setPatternBest(640);
    expect(s.patternBest, 640);
  });

  test('difficulty defaults to Auto, which starts at Medium', () async {
    final s = await makeService({});
    expect(s.difficulty, Difficulty.auto);
    expect(s.levelFor('reflex'), Level.medium);
  });

  test('a manual choice overrides Auto and is saved', () async {
    final s = await makeService({});
    await s.setDifficulty(Difficulty.hard);
    expect(s.difficulty, Difficulty.hard);
    expect(s.levelFor('memory'), Level.hard);
  });

  test('Auto gets harder after wins and easier after losses', () async {
    final s = await makeService({});
    await s.recordResult('reflex', Level.medium, true);
    expect(s.levelFor('reflex'), Level.medium);
    await s.recordResult('reflex', Level.medium, true);
    expect(s.levelFor('reflex'), Level.hard);

    await s.recordResult('memory', Level.medium, false);
    await s.recordResult('memory', Level.medium, false);
    expect(s.levelFor('memory'), Level.easy);
    // Other games are not affected.
    expect(s.levelFor('pattern'), Level.medium);
  });

  test('winning on Easy does not jump Auto straight to Hard', () async {
    final s = await makeService({});
    await s.recordResult('pattern', Level.easy, true);
    expect(s.levelFor('pattern'), Level.medium);
  });

  test('first Gauntlet of the day pays warm-up, wins and bonus', () async {
    final s = await makeService({});
    final day = DateTime(2026, 10, 22);
    final r = await s.onGauntletDone(day, 3, 700);
    expect(r.firstToday, isTrue);
    expect(r.points, 15 + 3 * 5 + 20);
    expect(s.rankPoints, 50);
    expect(s.gauntletTodayScore(day), 700);
    expect(s.gauntletBest, 700);
  });

  test('a second Gauntlet the same day pays nothing but keeps the best',
      () async {
    final s = await makeService({});
    final day = DateTime(2026, 10, 22);
    await s.onGauntletDone(day, 3, 700);
    final r = await s.onGauntletDone(day, 4, 800);
    expect(r.firstToday, isFalse);
    expect(r.points, 0);
    expect(s.rankPoints, 50);
    expect(s.gauntletTodayScore(day), 800);
    expect(s.gauntletTodayScore(DateTime(2026, 10, 23)), isNull);
  });

  test('Gauntlet skips the warm-up if a match already paid it today',
      () async {
    final s = await makeService({'warmupDay': '2026-10-22'});
    final r = await s.onGauntletDone(DateTime(2026, 10, 22), 2, 500);
    expect(r.points, 2 * 5 + 20);
  });

  test('vibration is on by default and can be switched off', () async {
    final s = await makeService({});
    expect(s.vibrationOn, isTrue);
    await s.setVibration(false);
    expect(s.vibrationOn, isFalse);
  });

  test('resetProgress erases progress but keeps settings', () async {
    final s = await makeService({
      'rp': 450,
      'streak': 9,
      'memoryBest': 7,
      'auto_reflex': 1.6,
      'vibration': false,
      'difficulty': 'hard',
      'onboarded': true,
    });
    await s.resetProgress();
    expect(s.rankPoints, 0);
    expect(s.streak, 0);
    expect(s.memoryBest, 0);
    expect(s.vibrationOn, isFalse);
    expect(s.difficulty, Difficulty.hard);
    expect(s.onboarded, isTrue);
    expect(s.levelFor('reflex'), Level.hard); // manual choice, not Auto
  });

  test('weekly points add up and reset on a new week', () async {
    final s = await makeService({});
    final thursday = DateTime(2026, 10, 22);
    await s.onGauntletDone(thursday, 3, 700); // pays 50 RP
    expect(s.weeklyPoints(thursday), 50);
    expect(s.weeklyPoints(DateTime(2026, 10, 25)), 50); // same week, Sunday
    expect(s.weeklyPoints(DateTime(2026, 10, 26)), 0); // next Monday
  });

  test('Gauntlet history keeps the best score per day', () async {
    final s = await makeService({});
    final day = DateTime(2026, 10, 22);
    await s.onGauntletDone(day, 3, 700);
    await s.onGauntletDone(day, 2, 500);
    expect(s.gauntletHistory()['2026-10-22'], 700);
  });

  test('fastest reaction time is remembered', () async {
    final s = await makeService({});
    expect(s.reflexBestMs, 0);
    await s.noteReflexTime(310);
    await s.noteReflexTime(450);
    await s.noteReflexTime(260);
    expect(s.reflexBestMs, 260);
    await s.noteReflexTime(0);
    expect(s.reflexBestMs, 260);
  });

  test('first win unlocks First blood once', () async {
    final s = await makeService({});
    expect(await s.checkAchievements(), isEmpty);
    await s.recordResult('reflex', Level.medium, true);
    final first = await s.checkAchievements();
    expect([for (final a in first) a.id], contains('first_win'));
    expect(await s.checkAchievements(), isEmpty);
    expect(s.unlockedAchievements, contains('first_win'));
  });

  test('a Hard win counts, a Hard loss does not', () async {
    final s = await makeService({});
    await s.recordResult('memory', Level.hard, false);
    expect(s.hardWins, 0);
    await s.recordResult('memory', Level.hard, true);
    expect(s.hardWins, 1);
    expect(s.totalWins, 1);
  });

  test('three days in a row unlock the 3-day streak badge', () async {
    final s = await makeService({});
    await s.onAppOpen(DateTime(2026, 10, 1));
    await s.onAppOpen(DateTime(2026, 10, 2));
    await s.onAppOpen(DateTime(2026, 10, 3));
    expect(s.bestStreak, 3);
    final ids = [for (final a in await s.checkAchievements()) a.id];
    expect(ids, contains('streak_3'));
    expect(ids, isNot(contains('streak_7')));
  });

  test('reaching Sharp rank is remembered even if the rank later drops',
      () async {
    final s = await makeService({});
    for (var i = 0; i < 10; i++) {
      await s.onLevelPassed();
    }
    expect(s.rank, Rank.sharp);
    expect(s.highestRankIndex, Rank.sharp.index);
    await s.onAppOpen(DateTime(2026, 10, 1));
    await s.onAppOpen(DateTime(2026, 10, 20)); // long gap, rank drops
    expect(s.rank, Rank.rookie);
    expect(s.highestRankIndex, Rank.sharp.index);
  });

  test('a perfect Gauntlet is counted', () async {
    final s = await makeService({});
    await s.onGauntletDone(DateTime(2026, 10, 22), 4, 900);
    expect(s.perfectGauntlets, 1);
    final ids = [for (final a in await s.checkAchievements()) a.id];
    expect(ids, containsAll(['gauntlet_1', 'gauntlet_800', 'perfect']));
  });

  test('reset progress clears badges', () async {
    final s = await makeService({});
    await s.recordResult('reflex', Level.medium, true);
    await s.checkAchievements();
    await s.resetProgress();
    expect(s.unlockedAchievements, isEmpty);
    expect(s.totalWins, 0);
  });

  test('daily twist is the same for the same date', () {
    final a = DailyTwist.forDate(DateTime(2026, 10, 21, 8));
    final b = DailyTwist.forDate(DateTime(2026, 10, 21, 22));
    expect(a.title, b.title);
  });
}
