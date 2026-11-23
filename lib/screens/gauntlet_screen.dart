import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads_service.dart';
import '../core/game_result.dart';
import '../core/rank_service.dart';
import '../core/theme.dart';
import '../core/zed_streak.dart';
import '../games/memory/memory_screen.dart';
import '../games/pattern/pattern_screen.dart';
import '../games/precision/precision_screen.dart';
import '../games/quiz/quiz_screen.dart';
import '../games/quiz/quiz_specs.dart';
import '../games/reflex/reflex_screen.dart';
import '../widgets/fx_widgets.dart';

/// Plays all six games in a row and adds up one score out of 1000.
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
    'Math Rush',
    'Color Clash',
  ];

  /// Wins needed to beat Zed (two thirds of the games).
  static const int _winTarget = 4;
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
  bool _doubled = false;
  ZedStreakResult? _zedStreak;

  Widget _screenFor(int i, int seed) {
    switch (i) {
      case 0:
        return ReflexScreen(rank: widget.rank, gauntlet: true);
      case 1:
        return MemoryScreen(rank: widget.rank, gauntlet: true, seed: seed + 1);
      case 2:
        return PrecisionScreen(
            rank: widget.rank, gauntlet: true, seed: seed + 2);
      case 3:
        return PatternScreen(rank: widget.rank, gauntlet: true, seed: seed + 3);
      case 4:
        return QuizScreen(
            spec: const MathRushSpec(),
            rank: widget.rank,
            gauntlet: true,
            seed: seed + 4);
      default:
        return QuizScreen(
            spec: const ColorClashSpec(),
            rank: widget.rank,
            gauntlet: true,
            seed: seed + 5);
    }
  }

  Future<void> _start() async {
    final seed = DailyTwist.seedForDate(DateTime.now());
    setState(() {
      _results.clear();
      _done = false;
      _reward = null;
      _doubled = false;
      _zedStreak = null;
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
        await widget.rank.onGauntletDone(DateTime.now(), _wins, _total,
            games: _names.length);
    final streak = await widget.rank.zedStreak
        .onGauntletResult(DateTime.now(), beatZed: _wins >= _winTarget);
    widget.ads?.onMatchFinished();
    if (!mounted) return;
    setState(() {
      _reward = reward;
      _zedStreak = streak;
      _done = true;
    });
  }

  int get _wins => _results.where((r) => r.won).length;
  /// Each game is worth up to 250; scaled so the whole run is out of 1000.
  int get _total =>
      _results.fold<int>(0, (sum, r) => sum + r.score) * 4 ~/ _names.length;

  String get _verdict {
    if (_wins >= _winTarget) return 'YOU BEAT ZED';
    if (_wins == _winTarget - 1) return 'DRAW';
    return 'ZED WINS';
  }

  Color get _verdictColor {
    if (_wins >= _winTarget) return AppColors.lime;
    if (_wins == _winTarget - 1) return AppColors.amber;
    return AppColors.coralSoft;
  }

  Future<void> _copyResult() async {
    final now = DateTime.now();
    final days = _zedStreak?.current ?? 0;
    final streakText =
        days >= 2 ? ' Zed Streak: ${ZedStreak.daysLabel(days)}.' : '';
    final text =
        'Beat the Bot, Daily Gauntlet ${now.day} ${_months[now.month - 1]}: '
        '$_total points, beat Zed in $_wins of ${_names.length} games.'
        '$streakText';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Result copied. Paste it to a friend.')),
    );
  }

  void _doubleReward(int points) {
    widget.ads?.showRewarded(
      onReward: () async {
        await widget.rank.doubleGauntletReward(DateTime.now(), points);
        if (mounted) setState(() => _doubled = true);
      },
      onNotReady: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ad not ready yet. Try again in a moment.')),
        );
      },
    );
  }

  void _home() {
    widget.ads?.showInterstitialIfDue();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ads = widget.ads;
    return NeonScaffold(
      bottomNavigationBar: ads == null ? null : AdBanner(ads: ads),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: _done ? _resultView() : _introView(),
        ),
      ),
    );
  }

  List<Widget> _introView() {
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
        'Six games in a row against Zed. Beat him in 4 of 6 to win.',
        style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.4),
      ),
      const SizedBox(height: 12),
      _zedStreakNote(),
      const SizedBox(height: 18),
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
      if (widget.rank.gauntletTodayScore(DateTime.now()) != null) ...[
        Text(
          "Today's best: ${widget.rank.gauntletTodayScore(DateTime.now())} points",
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.amber, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
      ],
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

  /// The Zed Streak line on the intro screen.
  Widget _zedStreakNote() {
    final now = DateTime.now();
    final zs = widget.rank.zedStreak;
    final days = zs.current(now);
    final String text;
    if (days == 0) {
      text = 'ZED STREAK: beat Zed every day to build it. '
          'Miss a day and it goes back to zero.';
    } else if (zs.beatToday(now)) {
      text = 'ZED STREAK: ${ZedStreak.daysLabel(days)}. Safe for today.';
    } else {
      text = 'ZED STREAK: ${ZedStreak.daysLabel(days)}. '
          'Beat Zed today or lose it.';
    }
    final shields = zs.shields;
    final runs = zs.beatToday(now)
        ? ''
        : ' Counting runs left today: ${zs.attemptsLeft(now)} of ${ZedStreak.maxAttempts}.';
    final full = '$text$runs';
    return Text(
      shields > 0 ? '$full  Shields: $shields.' : full,
      style: const TextStyle(
          color: AppColors.amber,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          height: 1.4),
    );
  }

  /// The Zed Streak lines on the result screen.
  List<Widget> _zedStreakResult() {
    final z = _zedStreak;
    if (z == null) return const <Widget>[];
    final beat = _wins >= _winTarget;
    Widget line(String text, Color color, {bool bold = true}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        );
    final lines = <Widget>[const SizedBox(height: 10)];
    if (z.increased) {
      lines.add(line('ZED STREAK: ${ZedStreak.daysLabel(z.current)}',
          AppColors.lime));
      if (z.isNewBest) {
        lines.add(line('New personal best!', AppColors.amber));
      }
      if (z.milestone != null) {
        lines.add(line('Milestone: ${z.milestone} days in a row.',
            AppColors.amber));
      }
      if (z.shieldEarned) {
        lines.add(line('Shield earned. It saves you from one missed day.',
            AppColors.amber));
      }
    } else if (z.limitHit) {
      lines.add(line(
          'You beat Zed, but only the first ${ZedStreak.maxAttempts} runs '
          'each day count for the streak. Try again tomorrow.',
          AppColors.coralSoft));
    } else if (beat) {
      lines.add(line('Zed Streak: ${ZedStreak.daysLabel(z.current)}. '
          'Today is already counted.', AppColors.muted, bold: false));
    } else if (z.current > 0 && z.attemptsLeft > 0) {
      lines.add(line(
          'Zed won this run. Play again and beat him today, or your '
          '${ZedStreak.daysLabel(z.current)} Zed Streak ends tonight. '
          '${z.attemptsLeft} counting run left.',
          AppColors.coralSoft));
    } else if (z.current > 0) {
      lines.add(line(
          'Zed won, and no counting runs are left today. Your '
          '${ZedStreak.daysLabel(z.current)} Zed Streak ends tonight.',
          AppColors.coralSoft));
    } else if (z.attemptsLeft == 0) {
      lines.add(line(
          'No counting runs left today. Start your Zed Streak tomorrow.',
          AppColors.muted,
          bold: false));
    }
    return lines;
  }

  List<Widget> _resultView() {
    final reward = _reward;
    final rankUp = reward?.rankUp;
    final String rewardText;
    if (reward == null || !reward.firstToday) {
      rewardText = 'Practice run. Rewards count once a day.';
    } else {
      rewardText = _doubled
          ? '+${reward.points * 2} RP earned (doubled)'
          : '+${reward.points} RP earned';
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
      Text('out of 1000 · beat Zed in $_wins of ${_names.length}',
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
      ..._zedStreakResult(),
      if (widget.ads != null &&
          reward != null &&
          reward.firstToday &&
          reward.points > 0 &&
          !_doubled &&
          !widget.rank.gauntletDoubled(DateTime.now())) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _doubleReward(reward.points),
          icon: const Icon(Icons.play_circle_outline_rounded),
          label: Text("Watch ad: double today's RP (+${reward.points})"),
        ),
      ],
      const SizedBox(height: 18),
      FilledButton(onPressed: _copyResult, child: const Text('COPY MY RESULT')),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () {
          widget.ads?.showInterstitialIfDue();
          _start();
        },
        child: const Text('PLAY AGAIN (PRACTICE)'),
      ),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: _home, child: const Text('BACK TO HOME')),
    ];
  }
}
