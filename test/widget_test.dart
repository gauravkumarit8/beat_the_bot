import 'package:beat_the_bot/core/difficulty.dart';
import 'package:beat_the_bot/core/rank_service.dart';
import 'package:beat_the_bot/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<RankService> pumpHome(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
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
    await pumpHome(tester);

    expect(find.text('ZED-9'), findsOneWidget);
    expect(find.textContaining('ROOKIE'), findsWidgets);
    expect(find.text('Reflex'), findsOneWidget);
  });

  testWidgets('tapping Hard saves the difficulty', (tester) async {
    final rank = await pumpHome(tester);
    expect(rank.difficulty, Difficulty.auto);

    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();

    expect(rank.difficulty, Difficulty.hard);
  });
}
