import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/ads_service.dart';
import 'core/error_log.dart';
import 'core/fx.dart';
import 'core/haptics.dart';
import 'core/sfx.dart';
import 'games/quiz/quiz_specs.dart';
import 'core/rank_service.dart';
import 'core/reminder_service.dart';
import 'core/zed_skins.dart';
import 'core/theme.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Remember unexpected errors on this phone so testers can send them.
  ErrorLog.attach(prefs);
  FlutterError.onError = (details) {
    ErrorLog.record(details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLog.record(error, stack);
    return true;
  };
  final ads = AdsService(prefs);
  unawaited(ads.init());
  final rank = RankService(prefs);
  Haptics.enabled = rank.vibrationOn;
  Sfx.enabled = rank.soundOn;
  Fx.animations = !rank.reduceEffects;
  ColorClashSpec.markers = rank.colorBlindHelp;
  rank.onMatchResult = (won) => Sfx.play(won ? Sound.win : Sound.lose);
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
      // Very large system fonts would break the layouts, so cap the scaling.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.35,
        child: child ?? const SizedBox.shrink(),
      ),
      home: rank.onboarded
          ? MainShell(rank: rank, ads: ads, reminders: reminders)
          : OnboardingScreen(rank: rank, ads: ads, reminders: reminders),
    );
  }
}
