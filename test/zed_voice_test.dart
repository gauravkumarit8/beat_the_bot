import 'package:beat_the_bot/core/rank_service.dart';
import 'package:beat_the_bot/core/zed_voice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<RankService> makeService(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return RankService(await SharedPreferences.getInstance());
}

void main() {
  final now = DateTime(2026, 10, 22);

  test('a brand new player gets the first-meeting line', () async {
    final r = await makeService({});
    final line = zedHomeLine(rank: r, now: now, missedDays: 0);
    expect(line.text, contains('Pick a game'));
    expect(line.mood, ZedMood.neutral);
  });

  test('being away is mocked first', () async {
    final r = await makeService({'totalWins': 4, 'lossStreak': 5});
    final line = zedHomeLine(rank: r, now: now, missedDays: 3);
    expect(line.text, contains('3 days'));
    expect(line.mood, ZedMood.smug);
  });

  test('a losing streak is rubbed in', () async {
    final r = await makeService({'totalLosses': 3, 'lossStreak': 3});
    final line = zedHomeLine(rank: r, now: now, missedDays: 0);
    expect(line.text, contains('in a row'));
    expect(line.mood, ZedMood.smug);
  });

  test('a winning streak makes Zed angry', () async {
    final r = await makeService({'totalWins': 3, 'winStreak': 3});
    final line = zedHomeLine(rank: r, now: now, missedDays: 0);
    expect(line.mood, ZedMood.annoyed);
  });

  test('a pending revenge bonus is mentioned', () async {
    final r = await makeService({'totalLosses': 1, 'revenge': true});
    final line = zedHomeLine(rank: r, now: now, missedDays: 0);
    expect(line.text.toLowerCase(), contains('revenge'));
  });

  test('an Elite player surprises Zed', () async {
    final r = await makeService({'rp': 450, 'totalWins': 5});
    final line = zedHomeLine(rank: r, now: now, missedDays: 0);
    expect(line.mood, ZedMood.shocked);
  });

  test('the everyday line is stable within a day', () async {
    final r = await makeService({'totalWins': 2});
    final a = zedHomeLine(rank: r, now: now, missedDays: 0);
    final b = zedHomeLine(rank: r, now: now, missedDays: 0);
    expect(a.text, b.text);
  });
}
