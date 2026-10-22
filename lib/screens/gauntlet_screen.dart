import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads_service.dart';
import '../core/game_result.dart';
import '../core/rank_service.dart';
import '../core/theme.dart';
import '../games/memory/memory_screen.dart';
import '../games/pattern/pattern_screen.dart';
import '../games/precision/precision_screen.dart';
import '../games/reflex/reflex_screen.dart';

/// Plays all four games in a row and adds up one score out of 1000.
class GauntletScreen extends StatefulWidget {
  const GauntletScreen({super.key, required this.rank, this.ads});

  final RankService rank;
  final AdsService? ads;

  @override
  State<GauntletScreen> createState() => _GauntletScreenState();
}

class _GauntletScreenState extends State<GauntletScreen> {
  static const List<String> _names = [
    'Reflex',
    'Memory',
    'Precision',
    'Pattern',
  ];
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final List<GameResult> _results = [];
  bool _done = false;
  GauntletReward? _reward;

  Widget _screenFor(int i, int seed) {
    switch (i) {
      case 0:
        return ReflexScreen(rank: widget.rank, gauntlet: true);
      case 1:
        return MemoryScreen(rank: widget.rank, gauntlet: true, seed: seed + 1);
      case 2:
        return PrecisionScreen(
            rank: widget.rank, gauntlet: true, seed: seed + 2);
      default:
        return PatternScreen(rank: widget.rank, gauntlet: true, seed: seed + 3);
    }
  }

  Future<void> _start() async {
    final seed = DailyTwist.seedForDate(DateTime.now());
    setState(() {
      _results.clear();
      _done = false;
      _reward = null;
    });
    for (var i = 0; i < _names.length; i++) {
      final result = await Navigator.of(context).push<GameResult>(
        MaterialPageRoute<GameResult>(builder: (_) => _screenFor(i, seed)),
      );
      if (!mounted) return;
      if (result == null) {
        // The player left in the middle, so nothing is awarded.
        setState(() => _results.clear());
        return;
      }
      setState(() => _results.add(result));
    }
    final reward =
        await widget.rank.onGauntletDone(DateTime.now(), _wins, _total);
    widget.ads?.onMatchFinished();
    if (!mounted) return;
    setState(() {
      _reward = reward;
      _done = true;
    });
  }

  int get _wins => _results.where((r) => r.won).length;
  int get _total => _results.fold<int>(0, (sum, r) => sum + r.score);

  String get _verdict {
    if (_wins >= 3) return 'YOU BEAT ZED';
    if (_wins == 2) return 'DRAW';
    return 'ZED WINS';
  }

  Color get _verdictColor {
    if (_wins >= 3) return AppColors.lime;
    if (_wins == 2) return AppColors.amber;
    return AppColors.coralSoft;
  }

  Future<void> _copyResult() async {
    final now = DateTime.now();
    final text =
        'Beat the Bot, Daily Gauntlet ${now.day} ${_months[now.month - 1]}: '
        '$_total points, beat Zed in $_wins of 4 games.';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Result copied. Paste it to a friend.')),
    );
  }

  void _home() {
    widget.ads?.showInterstitialIfDue();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: _done ? _resultView() : _introView(),
        ),
      ),
    );
  }

  List<Widget> _introView() {
    final twist = DailyTwist.forDate(DateTime.now());
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      const SizedBox(height: 8),
      const Text('Daily Gauntlet',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text(
        'Four games in a row against Zed. Beat him in 3 of 4 to win.',
        style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.4),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("TODAY'S TWIST",
                style: TextStyle(
                    color: AppColors.muted, letterSpacing: 1, fontSize: 12)),
            const SizedBox(height: 6),
            Text(twist.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(twist.detail,
                style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          ],
        ),
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < _names.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text('${i + 1}',
                    style: const TextStyle(
                        color: AppColors.lime, fontWeight: FontWeight.w700)),
                const SizedBox(width: 14),
                Text(_names[i],
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      const SizedBox(height: 10),
      const Text(
        'Puzzles and patterns are the same for everyone today. '
        'Rewards count once a day; extra runs are practice.',
        style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
      ),
      const SizedBox(height: 18),
      FilledButton(onPressed: _start, child: const Text('START')),
    ];
  }

  Widget _row(GameResult r) {
    final color = r.won ? AppColors.lime : AppColors.coralSoft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(r.game,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Text('${r.score}',
                style: const TextStyle(color: AppColors.muted, fontSize: 15)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Text(r.won ? 'WIN' : 'LOSS',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultView() {
    final reward = _reward;
    final rankUp = reward?.rankUp;
    final String rewardText;
    if (reward == null || !reward.firstToday) {
      rewardText = 'Practice run. Rewards count once a day.';
    } else {
      rewardText = '+${reward.points} RP earned';
    }
    return [
      const SizedBox(height: 24),
      Text(_verdict,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: _verdictColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 2)),
      const SizedBox(height: 6),
      Text('$_total',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700)),
      Text('out of 1000 · beat Zed in $_wins of 4',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 15)),
      const SizedBox(height: 20),
      for (final r in _results) _row(r),
      const SizedBox(height: 6),
      Text(rewardText,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.amber, fontWeight: FontWeight.w700)),
      if (rankUp != null) ...[
        const SizedBox(height: 6),
        Text('RANK UP: ${rankUp.name.toUpperCase()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.amber, fontWeight: FontWeight.w700)),
      ],
      const SizedBox(height: 18),
      FilledButton(onPressed: _copyResult, child: const Text('COPY MY RESULT')),
      const SizedBox(height: 10),
      OutlinedButton(
          onPressed: _start, child: const Text('PLAY AGAIN (PRACTICE)')),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: _home, child: const Text('BACK TO HOME')),
    ];
  }
}
