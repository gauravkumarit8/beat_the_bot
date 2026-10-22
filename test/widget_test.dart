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

    tester.view.physicalSize = const Size(1170, 2532);
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

  testWidgets('settings can switch vibration off', (tester) async {
    final rank = await pumpApp(tester);
    expect(rank.vibrationOn, isTrue);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Vibration'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(rank.vibrationOn, isFalse);
  });
}
