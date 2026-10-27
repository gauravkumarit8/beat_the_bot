import 'package:flutter/material.dart';

import '../core/ads_service.dart';
import '../core/dare.dart';
import '../core/difficulty.dart';
import '../core/zed_voice.dart';
import '../widgets/zed_face.dart';
import '../core/rank_service.dart';
import '../core/theme.dart';
import '../games/memory/memory_screen.dart';
import 'gauntlet_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import '../games/pattern/pattern_screen.dart';
import '../games/precision/precision_screen.dart';
import '../games/reflex/reflex_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.rank, this.ads});

  final RankService rank;
  final AdsService? ads;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _missed = 0;

  @override
  void initState() {
    super.initState();
    _onOpen();
  }

  Future<void> _onOpen() async {
    final result = await widget.rank.onAppOpen(DateTime.now());
    if (!mounted) return;
    setState(() => _missed = result?.missedDays ?? 0);
    if (result != null && (result.rankDropped || result.usedFreeze)) {
      await showDialog<void>(
        context: context,
        builder: (_) => _ReturnDialog(result: result),
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
  }

  void _startGame(String game) {
    switch (game) {
      case 'reflex':
        _playReflex();
      case 'memory':
        _playMemory();
      case 'precision':
        _playPrecision();
      default:
        _playPattern();
    }
  }

  Future<void> _openProgress() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => ProgressScreen(rank: widget.rank)),
    );
    await _afterRoute();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) =>
              SettingsScreen(rank: widget.rank, ads: widget.ads)),
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

  @override
  Widget build(BuildContext context) {
    final ads = widget.ads;
    final rank = widget.rank;
    final twist = DailyTwist.forDate(DateTime.now());
    return Scaffold(
      bottomNavigationBar: ads == null ? null : AdBanner(ads: ads),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _TopRow(
              rank: rank,
              onSettings: _openSettings,
              onProgress: _openProgress,
            ),
            const SizedBox(height: 18),
            _ZedCard(rank: rank, missedDays: _missed),
            const SizedBox(height: 18),
            _TodayCard(twist: twist, rank: rank),
            if (ads != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _watchForFreeze,
                icon: const Icon(Icons.ac_unit_rounded),
                label: Text('Watch ad: earn a streak freeze (${rank.freezes})'),
              ),
            ],
            const SizedBox(height: 18),
            _DareCard(
              dare: dareForDay(DateTime.now()),
              done: rank.dareDone(DateTime.now()),
              onTap: () => _startGame(dareForDay(DateTime.now()).game),
            ),
            const SizedBox(height: 12),
            _GauntletCard(
              todayScore: rank.gauntletTodayScore(DateTime.now()),
              onTap: _playGauntlet,
            ),
            const SizedBox(height: 18),
            const Text('DIFFICULTY',
                style: TextStyle(
                    color: AppColors.muted, letterSpacing: 1, fontSize: 13)),
            const SizedBox(height: 10),
            _DifficultyBar(
              current: rank.difficulty,
              onChanged: _setDifficulty,
            ),
            const SizedBox(height: 18),
            const Text('PICK YOUR BATTLE',
                style: TextStyle(
                    color: AppColors.muted, letterSpacing: 1, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    title: 'Reflex',
                    subtitle: 'Zed: strong',
                    icon: Icons.bolt_rounded,
                    onTap: _playReflex,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeCard(
                    title: 'Memory',
                    subtitle: 'Zed: weak spot',
                    icon: Icons.grid_view_rounded,
                    onTap: _playMemory,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    title: 'Precision',
                    subtitle: 'Zed: average',
                    icon: Icons.adjust_rounded,
                    onTap: _playPrecision,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeCard(
                    title: 'Pattern',
                    subtitle: 'Zed: tricky',
                    icon: Icons.waves_rounded,
                    onTap: _playPattern,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.rank,
    required this.onSettings,
    required this.onProgress,
  });

  final RankService rank;
  final VoidCallback onSettings;
  final VoidCallback onProgress;

  @override
  Widget build(BuildContext context) {
    // Wrap (not Row) so long ranks or streaks drop to a second line
    // instead of overflowing on narrow phones.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${rank.rank.name.toUpperCase()} · ${rank.rankPoints} RP',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: AppColors.amber, size: 22),
            const SizedBox(width: 6),
            Text('${rank.streak} day streak',
                style: const TextStyle(
                    color: AppColors.amber, fontWeight: FontWeight.w700)),
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

class _ZedCard extends StatelessWidget {
  const _ZedCard({required this.rank, required this.missedDays});

  final RankService rank;
  final int missedDays;

  @override
  Widget build(BuildContext context) {
    final line = zedHomeLine(
      rank: rank,
      now: DateTime.now(),
      missedDays: missedDays,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          ZedFace(mood: line.mood, size: 72, backdrop: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ZED-9',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('"${line.text}"',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  'You ${rank.totalWins}  ·  Zed ${rank.totalLosses}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                if (rank.revengeReady)
                  Text(
                    'Revenge bonus ready: +${RankService.revengeBonus} RP',
                    style: const TextStyle(
                        color: AppColors.amber,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.twist, required this.rank});

  final DailyTwist twist;
  final RankService rank;

  @override
  Widget build(BuildContext context) {
    final current = rank.rank;
    final hasNext = current.index + 1 < Rank.values.length;
    final next = hasNext ? Rank.values[current.index + 1] : null;
    var progress = 1.0;
    var label = 'Top rank reached';
    if (next != null) {
      final from = rankThreshold[current]!;
      final to = rankThreshold[next]!;
      progress = ((rank.rankPoints - from) / (to - from)).clamp(0.0, 1.0);
      label = '${to - rank.rankPoints} RP to ${next.name.toUpperCase()}';
    }
    return Container(
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
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.line,
              color: AppColors.lime,
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 108,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: AppColors.lime, size: 28),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(subtitle,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
          child: const Text('LET\'S GO'),
        ),
      ],
    );
  }
}

class _DifficultyBar extends StatelessWidget {
  const _DifficultyBar({required this.current, required this.onChanged});

  final Difficulty current;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final hint = current == Difficulty.auto
        ? 'Auto adjusts to your wins and losses in each game.'
        : 'Zed plays at ${current.label} level in every game.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final d in Difficulty.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: d == Difficulty.values.last ? 0 : 8),
                  child: _chip(d),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(hint,
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }

  Widget _chip(Difficulty d) {
    final selected = d == current;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.lime : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(d),
          child: SizedBox(
            height: 44,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    d.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.bg : AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GauntletCard extends StatelessWidget {
  const _GauntletCard({required this.todayScore, required this.onTap});

  final int? todayScore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = todayScore;
    return Material(
      color: AppColors.lime,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.bg, size: 30),
              const SizedBox(width: 14),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done == null
                          ? '4 games. Same puzzles for everyone today.'
                          : 'Today: $done points. Play again for practice.',
                      style: const TextStyle(
                          color: AppColors.bg, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.bg, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _DareCard extends StatelessWidget {
  const _DareCard({
    required this.dare,
    required this.done,
    required this.onTap,
  });

  final DailyDare dare;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: done ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: done ? AppColors.line : AppColors.coral, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.whatshot_rounded,
                color: done ? AppColors.lime : AppColors.coral,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ZED'S DARE",
                        style: TextStyle(
                            color: AppColors.muted,
                            letterSpacing: 1,
                            fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(dare.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                done ? 'DONE' : '+${dare.reward} RP',
                style: TextStyle(
                  color: done ? AppColors.lime : AppColors.amber,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
