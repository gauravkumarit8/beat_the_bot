import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/rank_service.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(BeatTheBotApp(rank: RankService(prefs)));
}

class BeatTheBotApp extends StatelessWidget {
  const BeatTheBotApp({super.key, required this.rank});

  final RankService rank;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beat the Bot',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeScreen(rank: rank),
    );
  }
}
