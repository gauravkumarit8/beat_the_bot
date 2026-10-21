import 'package:beat_the_bot/core/rank_service.dart';
import 'package:beat_the_bot/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home screen shows Zed and the starting rank', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(BeatTheBotApp(rank: RankService(prefs)));
    await tester.pumpAndSettle();

    expect(find.text('ZED-9'), findsOneWidget);
    expect(find.textContaining('ROOKIE'), findsWidgets);
    expect(find.text('Reflex'), findsOneWidget);
  });
}
