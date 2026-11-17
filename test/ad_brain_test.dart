import 'package:beat_the_bot/core/ad_brain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AdBrain> make() async {
  SharedPreferences.setMockInitialValues({});
  return AdBrain(await SharedPreferences.getInstance());
}

void main() {
  test('with no history the pacing is gentle', () async {
    final b = await make();
    final now = DateTime(2026, 10, 22, 20, 5);
    expect(b.isPeak(now), isFalse);
    expect(b.matchesBetweenAds(now), 3);
    expect(b.minGap(now), const Duration(seconds: 120));
  });

  test('a habitual hour with a long session allows ads a little sooner',
      () async {
    final b = await make();
    for (var day = 1; day <= 10; day++) {
      b.onOpen(DateTime(2026, 10, day, 20, 0));
    }
    final now = DateTime(2026, 10, 11, 20, 10);
    b.onOpen(now);
    expect(b.isPeak(now), isTrue);
    expect(b.matchesBetweenAds(now), 3); // not engaged yet
    for (var i = 0; i < 4; i++) {
      b.onMatch(now);
    }
    expect(b.matchesBetweenAds(now), 2);
    expect(b.minGap(now), const Duration(seconds: 90));
    // Another time of day stays gentle.
    expect(b.matchesBetweenAds(DateTime(2026, 10, 11, 9)), 3);
  });

  test('leaving right after two ads backs the pacing off', () async {
    final b = await make();
    final t = DateTime(2026, 10, 22, 20, 0);
    for (var i = 0; i < 2; i++) {
      b.onInterstitialClosed(t.add(Duration(minutes: i * 5)));
      b.onAppPaused(t.add(Duration(minutes: i * 5, seconds: 8)));
    }
    expect(b.matchesBetweenAds(t.add(const Duration(minutes: 20))), 4);
    expect(b.minGap(t.add(const Duration(minutes: 20))),
        const Duration(seconds: 180));
    // Three days later it has forgotten.
    expect(b.matchesBetweenAds(t.add(const Duration(days: 4))), 3);
  });

  test('leaving long after an ad is not a quick exit', () async {
    final b = await make();
    final t = DateTime(2026, 10, 22, 20, 0);
    b.onInterstitialClosed(t);
    b.onAppPaused(t.add(const Duration(minutes: 2)));
    b.onInterstitialClosed(t.add(const Duration(minutes: 5)));
    b.onAppPaused(t.add(const Duration(minutes: 9)));
    expect(b.matchesBetweenAds(t.add(const Duration(minutes: 10))), 3);
  });

  test('paid events add up per format and by hour', () async {
    final b = await make();
    for (var i = 0; i < 16; i++) {
      b.onPaid(AdFormat.rewarded, 20000, DateTime(2026, 10, 22, 21));
    }
    b.onPaid(AdFormat.interstitial, 5000, DateTime(2026, 10, 22, 9));
    expect(b.averageMicros(AdFormat.rewarded), 20000);
    expect(b.averageMicros(AdFormat.interstitial), 5000);
    expect(b.richHours(), contains(21));
    expect(b.isPeak(DateTime(2026, 10, 23, 21, 30)), isTrue);
  });
}
