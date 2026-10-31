import 'package:beat_the_bot/core/challenge.dart';
import 'package:beat_the_bot/core/difficulty.dart';
import 'package:beat_the_bot/core/rank_service.dart';
import 'package:beat_the_bot/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<RankService> pumpApp(
    WidgetTester tester, {
    Map<String, Object> prefsValues = const {'onboarded': true},
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();

    // A tall screen, so the whole Home list is built and findable.
    tester.view.physicalSize = const Size(1170, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rank = RankService(prefs);
    await tester.pumpWidget(BeatTheBotApp(rank: rank));
    await tester.pumpAndSettle();
    return rank;
  }

  testWidgets('home screen shows Zed and the starting rank', (tester) async {
    await pumpApp(tester);

    expect(find.text('ZED-9'), findsOneWidget);
    expect(find.text("ZED'S DARE"), findsOneWidget);
    expect(find.textContaining('ROOKIE'), findsWidgets);
    expect(find.text('Reflex'), findsOneWidget);
  });

  testWidgets('tapping Hard saves the difficulty', (tester) async {
    final rank = await pumpApp(tester);
    expect(rank.difficulty, Difficulty.auto);

    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();

    expect(rank.difficulty, Difficulty.hard);
  });

  testWidgets('first launch shows onboarding, then Home', (tester) async {
    final rank = await pumpApp(tester, prefsValues: const {});
    expect(find.text('Meet Zed-9'), findsOneWidget);
    expect(rank.onboarded, isFalse);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();

    expect(rank.onboarded, isTrue);
    expect(find.text('ZED-9'), findsOneWidget);
  });

  testWidgets('progress screen has three tabs with their cards',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.insights_rounded));
    await tester.pumpAndSettle();

    // Overview tab
    expect(find.text('Brain age'), findsOneWidget);
    expect(find.textContaining("This week's goals"), findsOneWidget);
    expect(find.textContaining("Zed's look"), findsOneWidget);
    expect(find.text('Days you showed up'), findsOneWidget);

    // Stats tab
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Weekly ladder'), findsOneWidget);

    // Badges tab
    await tester.tap(find.text('Badges'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Achievements'), findsOneWidget);
  });

  testWidgets('challenge dialog rejects a bad code', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('ENTER CHALLENGE CODE'));
    await tester.pumpAndSettle();
    expect(find.text('Challenge code'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nonsense');
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();

    expect(find.text('That code does not look right.'), findsOneWidget);
  });

  testWidgets('a valid challenge code opens that game', (tester) async {
    await pumpApp(tester);
    const c =
        Challenge(game: 'memory', level: Level.easy, seed: 5, score: 7);

    await tester.tap(find.text('ENTER CHALLENGE CODE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), c.code);
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your friend held 7 tiles'), findsOneWidget);
  });

  testWidgets('Math Rush opens from Home', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Math Rush'));
    await tester.pumpAndSettle();

    expect(find.textContaining('MATH RUSH'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('settings can switch vibration off', (tester) async {
    final rank = await pumpApp(tester);
    expect(rank.vibrationOn, isTrue);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Vibration'), findsOneWidget);

    // Tap the whole row, which toggles the switch the same way a finger does.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(rank.vibrationOn, isFalse);
  });
}
