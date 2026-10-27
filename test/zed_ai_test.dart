import 'package:beat_the_bot/games/zed_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a handicap makes Zed slower on average', () {
    double average(ZedAi ai) {
      var total = 0;
      for (var i = 0; i < 300; i++) {
        total += ai.nextReactionMs();
      }
      return total / 300;
    }

    final normal = average(ZedAi());
    final slowed = average(ZedAi(handicap: 1.4));
    expect(slowed, greaterThan(normal + 50));
  });

  test('Zed always has something to say', () {
    final ai = ZedAi();
    for (var i = 0; i < 20; i++) {
      expect(ai.winLine(), isNotEmpty);
      expect(ai.loseLine(), isNotEmpty);
    }
  });
}
