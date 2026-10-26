import 'package:beat_the_bot/core/progress.dart';
import 'package:beat_the_bot/core/rank_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skills stay between 0 and 1 and rise with better results', () {
    expect(reflexSkill(200), 1);
    expect(reflexSkill(600), 0);
    expect(reflexSkill(250), greaterThan(reflexSkill(350)));
    expect(memorySkill(3), 0);
    expect(memorySkill(10), 1);
    expect(precisionSkill(95), 1);
    expect(precisionSkill(40), 0);
    expect(patternSkill(700), 1);
    expect(patternSkill(0), 0);
  });

  test('brain age is unknown until a game is played, then gets younger', () {
    expect(brainAge([]), isNull);
    expect(brainAge([0.0])!, 60);
    expect(brainAge([1.0])!, 20);
    expect(brainAge([0.8])!, lessThan(brainAge([0.3])!));
  });

  test('the ladder has ten entries and includes you', () {
    final now = DateTime(2026, 10, 22); // a Thursday
    final ladder = buildLadder(now: now, yourPoints: 120);
    expect(ladder.length, 10);
    expect(ladder.where((e) => e.isYou).length, 1);
    expect(yourPlace(ladder), inInclusiveRange(1, 10));
  });

  test('the ladder is the same for the same week and puts a big score first',
      () {
    final a = buildLadder(now: DateTime(2026, 10, 21), yourPoints: 50);
    final b = buildLadder(now: DateTime(2026, 10, 21), yourPoints: 50);
    expect([for (final e in a) '${e.name}:${e.points}'],
        [for (final e in b) '${e.name}:${e.points}']);
    final top = buildLadder(now: DateTime(2026, 10, 21), yourPoints: 5000);
    expect(yourPlace(top), 1);
  });

  test('week starts on Monday', () {
    final monday = RankService.weekStart(DateTime(2026, 10, 25)); // Sunday
    expect(monday.weekday, DateTime.monday);
    expect(RankService.dayKey(monday), '2026-10-19');
  });
}
