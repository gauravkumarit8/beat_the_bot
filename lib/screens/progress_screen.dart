import 'package:flutter/material.dart';

import '../core/achievements.dart';
import '../core/ads_service.dart';
import '../core/progress.dart';
import '../core/rank_service.dart';
import '../core/zed_skins.dart';
import '../core/zed_voice.dart';
import '../widgets/zed_face.dart';
import '../core/theme.dart';

/// Shows how the player is improving, plus a weekly ladder against bots.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.rank, this.ads});

  final RankService rank;
  final AdsService? ads;

  static const List<String> _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final skills = <double>[
      if (rank.reflexBestMs > 0) reflexSkill(rank.reflexBestMs),
      if (rank.memoryBest > 0) memorySkill(rank.memoryBest),
      if (rank.precisionBest > 0) precisionSkill(rank.precisionBest),
      if (rank.patternBest > 0) patternSkill(rank.patternBest),
    ];
    final age = brainAge(skills);
    final ladder = buildLadder(now: now, yourPoints: rank.weeklyPoints(now));

    final adsService = ads;
    return Scaffold(
      bottomNavigationBar:
          adsService == null ? null : AdBanner(ads: adsService),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const Text('Progress',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            _card(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(age == null ? '--' : '$age',
                      style: const TextStyle(
                          fontSize: 56,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: AppColors.lime)),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Brain age',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text(
                          'Just for fun. Based on your best results, and it '
                          'gets younger as you improve.',
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 13, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(child: _SkinPicker(rank: rank)),
            const SizedBox(height: 14),
            _card(child: _calendar(now)),
            const SizedBox(height: 14),
            _card(child: _chart(now)),
            const SizedBox(height: 14),
            _card(child: _skills()),
            const SizedBox(height: 14),
            _card(child: _ladder(ladder)),
            const SizedBox(height: 14),
            _card(child: _achievements()),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _calendar(DateTime now) {
    final played = rank.playDays();
    final today = DateTime(now.year, now.month, now.day);
    // Five weeks, Monday first, ending with the current week.
    final first = DateTime(today.year, today.month, today.day - (today.weekday - 1) - 28);
    var count = 0;
    final rows = <Widget>[];
    for (var w = 0; w < 5; w++) {
      final cells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final day = DateTime(first.year, first.month, first.day + w * 7 + d);
        final isFuture = day.isAfter(today);
        final isToday = day == today;
        final showed = played.contains(RankService.dayKey(day));
        if (showed) count++;
        cells.add(
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isFuture
                      ? Colors.transparent
                      : (showed ? AppColors.lime : AppColors.line),
                  borderRadius: BorderRadius.circular(8),
                  border: isToday
                      ? Border.all(color: AppColors.text, width: 2)
                      : (isFuture
                          ? Border.all(color: AppColors.line, width: 1)
                          : null),
                ),
              ),
            ),
          ),
        );
      }
      rows.add(Row(children: cells));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Days you showed up',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 2),
        Text('$count of the last 5 weeks',
            style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final l in _dayLetters)
              Expanded(
                child: Center(
                  child: Text(l,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ...rows,
      ],
    );
  }

  Widget _chart(DateTime now) {
    final history = rank.gauntletHistory();
    final days = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Gauntlet, last 7 days',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 12),
        Semantics(
          label: 'Bar chart of your Daily Gauntlet scores for the last 7 days',
          child: SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(child: _bar(days[i], history, isToday: i == 6)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bar(DateTime day, Map<String, int> history, {required bool isToday}) {
    final score = history[RankService.dayKey(day)] ?? 0;
    final height = score <= 0 ? 4.0 : (4 + 92 * (score / 1000)).clamp(4.0, 96.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (score > 0)
          Text('$score',
              maxLines: 1,
              style: const TextStyle(color: AppColors.muted, fontSize: 10)),
        const SizedBox(height: 4),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: isToday ? AppColors.lime : AppColors.line,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(_dayLetters[day.weekday - 1],
            style: TextStyle(
                color: isToday ? AppColors.lime : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _skills() {
    final reflex = rank.reflexBestMs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your best results',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 12),
        _skillRow('Reflex', reflex > 0 ? reflexSkill(reflex) : null,
            reflex > 0 ? '${(reflex / 1000).toStringAsFixed(3)}s' : '--'),
        _skillRow(
            'Memory',
            rank.memoryBest > 0 ? memorySkill(rank.memoryBest) : null,
            rank.memoryBest > 0 ? '${rank.memoryBest} tiles' : '--'),
        _skillRow(
            'Precision',
            rank.precisionBest > 0 ? precisionSkill(rank.precisionBest) : null,
            rank.precisionBest > 0 ? '${rank.precisionBest}%' : '--'),
        _skillRow(
            'Pattern',
            rank.patternBest > 0 ? patternSkill(rank.patternBest) : null,
            rank.patternBest > 0 ? '${rank.patternBest} pts' : '--'),
      ],
    );
  }

  Widget _skillRow(String name, double? skill, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: skill ?? 0,
                minHeight: 10,
                backgroundColor: AppColors.line,
                color: AppColors.lime,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _achievements() {
    final unlocked = rank.unlockedAchievements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Achievements: ${unlocked.length} of ${allAchievements.length}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        for (final a in allAchievements)
          _achievementRow(a, unlocked.contains(a.id)),
      ],
    );
  }

  Widget _achievementRow(Achievement a, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
            color: done ? AppColors.amber : AppColors.muted,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: done ? AppColors.text : AppColors.muted)),
                Text(a.description,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ),
          if (done)
            const Text('UNLOCKED',
                style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _ladder(List<LadderEntry> ladder) {
    final place = yourPlace(ladder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly ladder: you are #$place of ${ladder.length}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 2),
        const Text('Rival bots. Resets every Monday.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 12),
        for (var i = 0; i < ladder.length; i++) _ladderRow(i + 1, ladder[i]),
      ],
    );
  }

  Widget _ladderRow(int place, LadderEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: e.isYou ? AppColors.line : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: e.isYou ? Border.all(color: AppColors.lime, width: 1.5) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$place',
                style: TextStyle(
                    color: e.isYou ? AppColors.lime : AppColors.muted,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(e.name,
                style: TextStyle(
                    fontWeight: e.isYou ? FontWeight.w700 : FontWeight.w500)),
          ),
          Text('${e.points} RP',
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Lets the player pick Zed's look from the skins they have unlocked.
class _SkinPicker extends StatefulWidget {
  const _SkinPicker({required this.rank});

  final RankService rank;

  @override
  State<_SkinPicker> createState() => _SkinPickerState();
}

class _SkinPickerState extends State<_SkinPicker> {
  Future<void> _choose(ZedSkin skin) async {
    if (!widget.rank.isSkinUnlocked(skin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Locked. ${skin.hint}')),
      );
      return;
    }
    await widget.rank.setSkin(skin.id);
    if (mounted) setState(() {});
  }

  Widget _tile(ZedSkin skin) {
    final unlocked = widget.rank.isSkinUnlocked(skin);
    final active = widget.rank.activeSkin.id == skin.id;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _choose(skin),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.lime : AppColors.line,
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: unlocked ? 1 : 0.4,
              child: ZedFace(mood: ZedMood.neutral, size: 44, skin: skin),
            ),
            const SizedBox(height: 6),
            Text(skin.name,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            Text(
              active ? 'ACTIVE' : (unlocked ? 'TAP TO USE' : 'LOCKED'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? AppColors.lime : AppColors.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Zed's look",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 2),
        const Text('Unlock new looks with achievements.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final s in ZedSkins.all) _tile(s)],
        ),
      ],
    );
  }
}
