import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/ads_service.dart';
import 'core/haptics.dart';
import 'core/rank_service.dart';
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
  runApp(BeatTheBotApp(rank: rank, ads: ads));
}

class BeatTheBotApp extends StatelessWidget {
  const BeatTheBotApp({super.key, required this.rank, this.ads});

  final RankService rank;
  final AdsService? ads;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beat the Bot',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: rank.onboarded
          ? HomeScreen(rank: rank, ads: ads)
          : OnboardingScreen(rank: rank, ads: ads),
    );
  }
}
