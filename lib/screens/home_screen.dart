import 'package:flutter/material.dart';

import '../core/ads_service.dart';
import '../core/challenge.dart';
import '../core/dare.dart';
import '../core/difficulty.dart';
import '../core/weekly_goals.dart';
import '../core/zed_voice.dart';
import '../widgets/celebration.dart';
import '../widgets/challenge_dialog.dart';
import '../widgets/zed_face.dart';
import '../core/rank_service.dart';
import '../core/reminder_service.dart';
import '../core/theme.dart';
import '../games/memory/memory_screen.dart';
import 'gauntlet_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import '../games/pattern/pattern_screen.dart';
import '../games/precision/precision_screen.dart';
import '../games/quiz/quiz_screen.dart';
import '../games/quiz/quiz_specs.dart';
import '../games/reflex/reflex_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.rank,
    this.ads,
    this.reminders,
  });

  final RankService rank;
  final AdsService? ads;
  final ReminderService? reminders;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _missed = 0;
  int _lastRankIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastRankIndex = widget.rank.rank.index;
    _onOpen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app counts as showing up, so tomorrow's reminder is
    // rescheduled and today's is cancelled.
    if (state == AppLifecycleState.resumed) {
      widget.reminders?.refresh(widget.rank);
    }
  }

  Future<void> _enableReminder() async {
    final reminders = widget.reminders;
    if (reminders == null) return;
    final allowed = await reminders.askPermission();
    if (!mounted) return;
    if (!allowed) {
      await widget.rank.dismissReminderPrompt();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Notifications are off for this app. You can turn reminders on later in Settings.'),
        ),
      );
      return;
    }
    await widget.rank.setReminderOn(true);
    await reminders.refresh(widget.rank);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Daily reminder is on. Change the time in Settings.')),
    );
  }

  Future<void> _dismissReminderPrompt() async {
    await widget.rank.dismissReminderPrompt();
    if (mounted) setState(() {});
  }

  Future<void> _onOpen() async {
    final result = await widget.rank.onAppOpen(DateTime.now());
    if (!mounted) return;
    setState(() => _missed = result?.missedDays ?? 0);
    _lastRankIndex = widget.rank.rank.index;
    widget.reminders?.refresh(widget.rank);
    if (result != null && (result.rankDropped || result.usedFreeze)) {
      await showDialog<void>(
        context: context,
        builder: (_) => _ReturnDialog(result: result),
      );
    }
    final milestone = await widget.rank.takeStreakMilestone();
    if (milestone != null && mounted) {
      await showCelebration(
        context,
        title: 'STREAK MILESTONE',
        badge: '$milestone DAYS',
        subtitle: '$milestone days in a row. Zed is getting nervous.',
      );
    }
  }

  Future<void> _playReflex() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReflexScreen(rank: widget.rank, ads: widget.ads)),
    );
    await _afterRoute();
  }

  Future<void> _playMemory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => MemoryScreen(rank: widget.rank, ads: widget.ads)),
    );
    await _afterRoute();
  }

  Future<void> _playPrecision() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => PrecisionScreen(rank: widget.rank, ads: widget.ads)),
    );
    await _afterRoute();
  }

  Future<void> _playPattern() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => PatternScreen(rank: widget.rank, ads: widget.ads)),
    );
    await _afterRoute();
  }

  /// Runs after coming back from any screen: refresh, then announce revenge,
  /// dare and new badges.
  Future<void> _afterRoute() async {
    final unlocked = await widget.rank.checkAchievements();
    final notices = await widget.rank.takeNotices();
    if (!mounted) return;
    setState(() {});
    final lines = [
      ...notices,
      if (unlocked.isNotEmpty)
        'Achievement unlocked: ${unlocked.map((a) => a.title).join(', ')}',
    ];
    if (lines.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lines.join('\n')),
          duration: const Duration(seconds: 5),
        ),
      );
    }
    final current = widget.rank.rank;
    final climbed = current.index > _lastRankIndex;
    _lastRankIndex = current.index;
    if (climbed) {
      await showCelebration(
        context,
        title: 'RANK UP',
        badge: current.name.toUpperCase(),
        subtitle: 'You are now ${current.name.toUpperCase()}. Zed noticed.',
      );
    }
    // After two matches, a short ad when you come back to Home.
    widget.ads?.showInterstitialIfDue();
  }

  Future<void> _playQuiz(QuizSpec spec) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) =>
              QuizScreen(spec: spec, rank: widget.rank, ads: widget.ads)),
    );
    await _afterRoute();
  }

  void _startGame(String game) {
    switch (game) {
      case 'reflex':
        _playReflex();
      case 'memory':
        _playMemory();
      case 'precision':
        _playPrecision();
      case 'math':
        _playQuiz(const MathRushSpec());
      case 'color':
        _playQuiz(const ColorClashSpec());
      default:
        _playPattern();
    }
  }

  Future<void> _openProgress() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => ProgressScreen(rank: widget.rank, ads: widget.ads)),
    );
    await _afterRoute();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(
              rank: widget.rank,
              ads: widget.ads,
              reminders: widget.reminders)),
    );
    await _afterRoute();
  }

  Future<void> _playGauntlet() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => GauntletScreen(rank: widget.rank, ads: widget.ads)),
    );
    await _afterRoute();
  }

  Future<void> _enterChallenge() async {
    final challenge = await showDialog<Challenge>(
      context: context,
      builder: (_) => const ChallengeCodeDialog(),
    );
    if (challenge == null || !mounted) return;
    final Widget screen = switch (challenge.game) {
      'memory' =>
        MemoryScreen(rank: widget.rank, ads: widget.ads, challenge: challenge),
      'precision' => PrecisionScreen(
          rank: widget.rank, ads: widget.ads, challenge: challenge),
      'math' => QuizScreen(
          spec: const MathRushSpec(),
          rank: widget.rank,
          ads: widget.ads,
          challenge: challenge),
      'color' => QuizScreen(
          spec: const ColorClashSpec(),
          rank: widget.rank,
          ads: widget.ads,
          challenge: challenge),
      _ =>
        PatternScreen(rank: widget.rank, ads: widget.ads, challenge: challenge),
    };
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    await _afterRoute();
  }

  Future<void> _setDifficulty(Difficulty d) async {
    await widget.rank.setDifficulty(d);
    if (mounted) setState(() {});
  }

  void _watchForFreeze() {
    widget.ads?.showRewarded(
      onReward: () async {
        await widget.rank.addFreeze();
        if (mounted) setState(() {});
      },
      onNotReady: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad not ready yet. Try again in a moment.')),
        );
      },
    );
  }

  Future<void> _showDifficultySheet() async {
    final chosen = await showModalBottomSheet<Difficulty>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DifficultySheet(current: widget.rank.difficulty),
    );
    if (chosen != null) await _setDifficulty(chosen);
  }

  List<_GameInfo> _games() {
    final rank = widget.rank;
    String best(bool played, String text) => played ? 'Best $text' : 'Not played yet';
    final reflexMs = rank.reflexBestMs;
    return [
      _GameInfo(
        title: 'Reflex',
        icon: Icons.bolt_rounded,
        accent: AppColors.amber,
        line: best(reflexMs > 0, '${(reflexMs / 1000).toStringAsFixed(3)}s'),
        onTap: _playReflex,
      ),
      _GameInfo(
        title: 'Memory',
        icon: Icons.grid_view_rounded,
        accent: const Color(0xFF5BD6FF),
        line: best(rank.memoryBest > 0, '${rank.memoryBest} tiles'),
        onTap: _playMemory,
      ),
      _GameInfo(
        title: 'Precision',
        icon: Icons.adjust_rounded,
        accent: AppColors.coralSoft,
        line: best(rank.precisionBest > 0, '${rank.precisionBest}%'),
        onTap: _playPrecision,
      ),
      _GameInfo(
        title: 'Pattern',
        icon: Icons.waves_rounded,
        accent: const Color(0xFFB07CFF),
        line: best(rank.patternBest > 0, '${rank.patternBest} pts'),
        onTap: _playPattern,
      ),
      _GameInfo(
        title: 'Math Rush',
        icon: Icons.calculate_rounded,
        accent: AppColors.lime,
        line: best(rank.quizBest('math') > 0, '${rank.quizBest('math')} pts'),
        onTap: () => _playQuiz(const MathRushSpec()),
      ),
      _GameInfo(
        title: 'Color Clash',
        icon: Icons.palette_rounded,
        accent: const Color(0xFFFF4FD8),
        line: best(rank.quizBest('color') > 0, '${rank.quizBest('color')} pts'),
        onTap: () => _playQuiz(const ColorClashSpec()),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ads = widget.ads;
    final rank = widget.rank;
    final now = DateTime.now();
    final line = zedHomeLine(rank: rank, now: now, missedDays: _missed);
    final dare = dareForDay(now);
    final goalsDone =
        weeklyGoals.where((g) => rank.weeklyGoalClaimed(g.id, now)).length;
    final showReminder = widget.reminders != null &&
        !rank.reminderOn &&
        !rank.reminderPromptDismissed &&
        rank.totalWins + rank.totalLosses >= 1;

    return Scaffold(
      bottomNavigationBar: ads == null ? null : AdBanner(ads: ads),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _TopBar(
              rank: rank,
              onProgress: _openProgress,
              onSettings: _openSettings,
            ),
            const SizedBox(height: 14),
            _RankProgress(rank: rank),
            const SizedBox(height: 18),
            _HeroCard(
              rank: rank,
              line: line,
              gauntletScore: rank.gauntletTodayScore(now),
              onGauntlet: _playGauntlet,
            ),
            const SizedBox(height: 24),
            const _SectionLabel('TODAY'),
            const SizedBox(height: 10),
            SizedBox(
              height: 118,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _DareTile(
                    dare: dare,
                    done: rank.dareDone(now),
                    onTap: () => _startGame(dare.game),
                  ),
                  const SizedBox(width: 12),
                  _GoalsTile(
                    done: goalsDone,
                    total: weeklyGoals.length,
                    onTap: _openProgress,
                  ),
                  if (showReminder) ...[
                    const SizedBox(width: 12),
                    _ReminderTile(
                      onEnable: _enableReminder,
                      onDismiss: _dismissReminderPrompt,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionLabel('PLAY'),
                _DifficultyChip(
                  label: rank.difficulty.label,
                  onTap: _showDifficultySheet,
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final g in _games()) _GameCard(info: g)],
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _enterChallenge,
                  icon: const Icon(Icons.group_add_rounded, size: 20),
                  label: const Text('Enter challenge code'),
                ),
                if (ads != null)
                  TextButton.icon(
                    onPressed: _watchForFreeze,
                    icon: const Icon(Icons.ac_unit_rounded, size: 20),
                    label: Text('Streak freezes: ${rank.freezes} · get more'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces of the Home screen
// ---------------------------------------------------------------------------

class _GameInfo {
  const _GameInfo({
    required this.title,
    required this.icon,
    required this.accent,
    required this.line,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String line;
  final VoidCallback onTap;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.rank,
    required this.onProgress,
    required this.onSettings,
  });

  final RankService rank;
  final VoidCallback onProgress;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    // Wrap, not Row, so a long rank on a narrow phone drops the icons to a
    // second line instead of overflowing.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${rank.rank.name.toUpperCase()} · ${rank.rankPoints} RP',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: '${rank.streak} day streak',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: AppColors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text('${rank.streak}',
                        style: const TextStyle(
                            color: AppColors.amber,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Progress',
              onPressed: onProgress,
              icon: const Icon(Icons.insights_rounded, color: AppColors.muted),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_rounded, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _RankProgress extends StatelessWidget {
  const _RankProgress({required this.rank});

  final RankService rank;

  @override
  Widget build(BuildContext context) {
    final current = rank.rank;
    final hasNext = current.index + 1 < Rank.values.length;
    final next = hasNext ? Rank.values[current.index + 1] : null;
    var progress = 1.0;
    var caption = 'Top rank reached';
    if (next != null) {
      final from = rankThreshold[current]!;
      final to = rankThreshold[next]!;
      progress = ((rank.rankPoints - from) / (to - from)).clamp(0.0, 1.0);
      caption = '${to - rank.rankPoints} RP to ${next.name.toUpperCase()}';
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.line,
            color: AppColors.lime,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(current.name.toUpperCase(),
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            Text(caption,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.amber, width: 1.2),
      ),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

/// Zed, what he says, your record against him, and the one big action.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.rank,
    required this.line,
    required this.gauntletScore,
    required this.onGauntlet,
  });

  final RankService rank;
  final ZedLine line;
  final int? gauntletScore;
  final VoidCallback onGauntlet;

  @override
  Widget build(BuildContext context) {
    final subtitle = gauntletScore == null
        ? '4 games · same puzzles for everyone today'
        : 'Today: $gauntletScore points · tap to play again';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF212B5E), Color(0xFF151B38)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ZedFace(mood: line.mood, size: 84, backdrop: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ZED-9',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('"${line.text}"',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 14, height: 1.3)),
                    const SizedBox(height: 8),
                    Text(
                      'You ${rank.totalWins}  ·  Zed ${rank.totalLosses}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (rank.revengeReady ||
              rank.winStreak + 1 >= RankService.hotStreakFrom) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (rank.revengeReady)
                    const _StatusChip(
                        'REVENGE BONUS +${RankService.revengeBonus} RP'),
                  if (rank.winStreak + 1 >= RankService.hotStreakFrom)
                    const _StatusChip(
                        'HOT STREAK +${RankService.hotStreakBonus} RP PER WIN'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Material(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onGauntlet,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.flag_rounded, color: AppColors.bg, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'DAILY GAUNTLET',
                              style: TextStyle(
                                color: AppColors.bg,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.bg, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded,
                        color: AppColors.bg, size: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small card in the "Today" strip.
class _TileShell extends StatelessWidget {
  const _TileShell({
    required this.onTap,
    required this.child,
    this.borderColor = AppColors.line,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 224,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DareTile extends StatelessWidget {
  const _DareTile({
    required this.dare,
    required this.done,
    required this.onTap,
  });

  final DailyDare dare;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      onTap: done ? null : onTap,
      borderColor: done ? AppColors.line : AppColors.coral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.whatshot_rounded,
                color: done ? AppColors.lime : AppColors.coral,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text("ZED'S DARE",
                  style: TextStyle(
                      color: AppColors.muted,
                      letterSpacing: 1,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          Text(dare.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          Text(
            done ? 'DONE' : '+${dare.reward} RP',
            style: TextStyle(
              color: done ? AppColors.lime : AppColors.amber,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsTile extends StatelessWidget {
  const _GoalsTile({
    required this.done,
    required this.total,
    required this.onTap,
  });

  final int done;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.flag_circle_rounded, color: AppColors.amber, size: 18),
              SizedBox(width: 6),
              Text('WEEKLY GOALS',
                  style: TextStyle(
                      color: AppColors.muted,
                      letterSpacing: 1,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          Text('$done of $total done',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              backgroundColor: AppColors.line,
              color: AppColors.amber,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.onEnable, required this.onDismiss});

  final VoidCallback onEnable;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      onTap: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  color: AppColors.lime, size: 18),
              SizedBox(width: 6),
              Text('DAILY REMINDER',
                  style: TextStyle(
                      color: AppColors.muted,
                      letterSpacing: 1,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const Text('Let Zed nudge you at 7 PM?',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('NOT NOW'),
              ),
              TextButton(
                onPressed: onEnable,
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('TURN ON'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Difficulty: $label',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              const Icon(Icons.expand_more_rounded,
                  size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultySheet extends StatelessWidget {
  const _DifficultySheet({required this.current});

  final Difficulty current;

  static String _describe(Difficulty d) => switch (d) {
        Difficulty.easy => 'Zed is slower and more forgiving. Good for learning.',
        Difficulty.medium => 'A fair fight.',
        Difficulty.hard => 'Zed is sharp, and the games have extra twists.',
        Difficulty.auto => 'Adapts to your wins and losses in each game.',
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text('Difficulty',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            for (final d in Difficulty.values)
              ListTile(
                leading: Icon(
                  d == current
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: d == current ? AppColors.lime : AppColors.muted,
                ),
                title: Text(d.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_describe(d),
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 13)),
                onTap: () => Navigator.of(context).pop(d),
              ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.info});

  final _GameInfo info;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: info.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(info.icon, color: info.accent, size: 26),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(info.title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 2),
                  Text(info.line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReturnDialog extends StatelessWidget {
  const _ReturnDialog({required this.result});

  final ReturnResult result;

  @override
  Widget build(BuildContext context) {
    final String message;
    if (result.rankDropped) {
      message = 'You were away ${result.missedDays} days, so your rank '
          'dropped from ${result.before.name.toUpperCase()} to '
          '${result.after.name.toUpperCase()}. Win games today to climb back.';
    } else {
      message = 'You were away ${result.missedDays} days, but your streak '
          'freeze protected your rank.';
    }
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Welcome back'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("LET'S GO"),
        ),
      ],
    );
  }
}
