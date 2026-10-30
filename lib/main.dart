import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/ads_service.dart';
import 'core/haptics.dart';
import 'core/rank_service.dart';
import 'core/reminder_service.dart';
import 'core/zed_skins.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final ads = AdsService(prefs);
  unawaited(ads.init());
  final rank = RankService(prefs);
  Haptics.enabled = rank.vibrationOn;
  ZedSkins.current = rank.activeSkin;
  final reminders = ReminderService();
  await reminders.init();
  runApp(BeatTheBotApp(rank: rank, ads: ads, reminders: reminders));
}

class BeatTheBotApp extends StatelessWidget {
  const BeatTheBotApp({
    super.key,
    required this.rank,
    this.ads,
    this.reminders,
  });

  final RankService rank;
  final AdsService? ads;
  final ReminderService? reminders;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beat the Bot',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: rank.onboarded
          ? HomeScreen(rank: rank, ads: ads, reminders: reminders)
          : OnboardingScreen(rank: rank, ads: ads, reminders: reminders),
    );
  }
}
