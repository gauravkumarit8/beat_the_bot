import 'package:flutter/material.dart';

import '../core/ads_service.dart';
import '../core/rank_service.dart';
import '../core/theme.dart';
import '../games/memory/memory_screen.dart';
import '../games/reflex/reflex_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.rank, this.ads});

  final RankService rank;
  final AdsService? ads;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _onOpen();
  }

  Future<void> _onOpen() async {
    final result = await widget.rank.onAppOpen(DateTime.now());
    if (!mounted) return;
    setState(() {});
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
    if (mounted) setState(() {});
  }

  Future<void> _playMemory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => MemoryScreen(rank: widget.rank, ads: widget.ads)),
    );
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
            _TopRow(rank: rank),
            const SizedBox(height: 18),
            const _ZedCard(),
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
            const Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    title: 'Precision',
                    subtitle: 'Coming soon',
                    icon: Icons.adjust_rounded,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ModeCard(
                    title: 'Pattern',
                    subtitle: 'Coming soon',
                    icon: Icons.waves_rounded,
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
  const _TopRow({required this.rank});

  final RankService rank;

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
      ],
    );
  }
}

class _ZedCard extends StatelessWidget {
  const _ZedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.line,
            child: Icon(Icons.smart_toy_rounded,
                size: 38, color: AppColors.coral),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ZED-9',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('"Pick a game. I\'ll pick your weakness."',
                    style: TextStyle(color: AppColors.muted, fontSize: 14)),
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
