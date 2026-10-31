import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/ad_actions.dart';
import '../../core/ads_service.dart';
import '../../core/brag.dart';
import '../../core/challenge.dart';
import '../../core/difficulty.dart';
import '../../core/haptics.dart';
import '../../core/rank_service.dart';
import '../../core/theme.dart';
import '../../core/zed_voice.dart';
import '../../widgets/challenge_panel.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/game_banner.dart';
import '../../widgets/zed_face.dart';
import 'quiz_specs.dart';

enum _Phase { ready, asking, revealed, matchOver }

/// Plays any [QuizSpec]: ten questions against the clock and against Zed.
/// Faster correct answers score more. The highest total wins.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.spec,
    required this.rank,
    this.ads,
    this.challenge,
  });

  final QuizSpec spec;
  final RankService rank;
  final AdsService? ads;

  /// A friend's challenge to beat. Replays their seed and level.
  final Challenge? challenge;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  final Random _zedRng = Random();
  late final AnimationController _ctrl = AnimationController(vsync: this);

  late Level _level;
  late int _matchSeed;
  bool _weak = false;

  _Phase _phase = _Phase.ready;
  int _round = 1;
  QuizQuestion? _q;
  int? _picked;
  bool _timedOut = false;
  int _youTotal = 0;
  int _zedTotal = 0;
  int _gainYou = 0;
  int _gainZed = 0;
  bool _won = false;
  bool _newBest = false;
  Rank? _rankedUp;
  String _taunt = '';
  ZedMood _mood = ZedMood.neutral;

  @override
  void initState() {
    super.initState();
    _level = widget.challenge?.level ?? widget.rank.levelFor(widget.spec.id);
    _reseed();
    _weak = widget.challenge == null && widget.rank.zedWeakened;
    if (_weak) widget.rank.setZedWeakened(false);
    _ctrl.duration = widget.spec.timeFor(_level);
    final c = widget.challenge;
    _taunt = c != null
        ? 'Your friend scored ${c.score}. Beat that.'
        : widget.spec.opening;
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && _phase == _Phase.asking) {
        _answer(null);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _reseed() {
    _matchSeed = widget.challenge?.seed ?? Random().nextInt(1 << 24);
  }

  void _startQuestion() {
    // Same seed and round always give the same question (challenge codes).
    final q = widget.spec.question(
      round: _round,
      level: _level,
      rng: Random(_matchSeed * 100 + _round),
    );
    setState(() {
      _q = q;
      _picked = null;
      _timedOut = false;
      _phase = _Phase.asking;
    });
    _ctrl.forward(from: 0);
  }

  void _answer(int? option) {
    if (_phase != _Phase.asking) return;
    _ctrl.stop();
    final q = _q!;
    final correct = option != null && option == q.answer;
    final remaining = 1 - _ctrl.value;
    final gain = correct ? 100 + (50 * remaining).round() : 0;
    final chance = widget.spec.zedAccuracy(_level) - (_weak ? 0.15 : 0);
    final zedGain =
        _zedRng.nextDouble() < chance ? 110 + _zedRng.nextInt(30) : 0;
    if (correct) {
      Haptics.selection();
    } else {
      Haptics.heavy();
    }
    setState(() {
      _picked = option;
      _timedOut = option == null;
      _gainYou = gain;
      _gainZed = zedGain;
      _youTotal += gain;
      _zedTotal += zedGain;
      _taunt = gain > zedGain ? 'Hm. Lucky.' : 'Too slow. Or too wrong.';
      _mood = gain > zedGain ? ZedMood.annoyed : ZedMood.smug;
      _phase = _Phase.revealed;
    });
  }

  void _next() {
    if (_round >= widget.spec.rounds) {
      _finish();
      return;
    }
    setState(() => _round++);
    _startQuestion();
  }

  Future<void> _finish() async {
    final won = _youTotal > _zedTotal;
    final challenge = widget.challenge;
    if (challenge != null) {
      final beat = _youTotal > challenge.score;
      await widget.rank.recordChallenge(beat);
      if (!mounted) return;
      setState(() {
        _won = beat;
        _mood = beat ? ZedMood.shocked : ZedMood.smug;
        _phase = _Phase.matchOver;
      });
      return;
    }
    await widget.rank.recordResult(widget.spec.id, _level, won);
    Rank? up;
    final improved = _youTotal > widget.rank.quizBest(widget.spec.id);
    if (improved) {
      await widget.rank.setQuizBest(widget.spec.id, _youTotal);
      up = await widget.rank.onLevelPassed();
    }
    if (won) {
      final winUp = await widget.rank.onWinAgainstZed();
      up = winUp ?? up;
    }
    final warmupUp = await widget.rank.onWarmupDone(DateTime.now());
    up = warmupUp ?? up;
    widget.ads?.onMatchFinished();
    if (!mounted) return;
    setState(() {
      _won = won;
      _mood = won ? ZedMood.shocked : ZedMood.smug;
      _newBest = improved;
      _rankedUp = up;
      _phase = _Phase.matchOver;
    });
  }

  void _rematch() {
    _ctrl.stop();
    _level = widget.rank.levelFor(widget.spec.id);
    _weak = widget.rank.zedWeakened;
    if (_weak) widget.rank.setZedWeakened(false);
    _reseed();
    _ctrl.duration = widget.spec.timeFor(_level);
    setState(() {
      _phase = _Phase.ready;
      _round = 1;
      _q = null;
      _picked = null;
      _youTotal = 0;
      _zedTotal = 0;
      _rankedUp = null;
      _newBest = false;
      _mood = ZedMood.neutral;
      _taunt = _weak
          ? 'You slowed me down? Cheater. I still win.'
          : widget.spec.opening;
    });
  }

  void _challengeFriend() => copyBrag(
        context,
        Challenge(
          game: widget.spec.id,
          level: _level,
          seed: _matchSeed,
          score: _youTotal,
        ).shareText,
      );

  String _revealSummary() {
    final q = _q!;
    final String head;
    if (_timedOut) {
      head = "Time's up! It was ${q.options[q.answer].label}";
    } else if (_picked == q.answer) {
      head = 'Correct! +$_gainYou';
    } else {
      head = 'Not quite. It was ${q.options[q.answer].label}';
    }
    return '$head  ·  Zed +$_gainZed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: GameBanner(ads: widget.ads),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _hud(),
              const SizedBox(height: 16),
              _tauntBubble(),
              const SizedBox(height: 8),
              DifficultyBadge(
                level: _level,
                auto: widget.challenge == null &&
                    widget.rank.difficulty == Difficulty.auto,
              ),
              const SizedBox(height: 8),
              _timerBar(),
              Expanded(child: Center(child: _promptArea())),
              _options(),
              const SizedBox(height: 16),
              _bottomPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${widget.spec.title.toUpperCase()} · ROUND $_round / ${widget.spec.rounds}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _tauntBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ZedFace(mood: _mood, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text('ZED-9: "$_taunt"',
                style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _timerBar() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _phase == _Phase.asking ? 1 - _ctrl.value : 0,
            minHeight: 10,
            backgroundColor: AppColors.line,
            color: AppColors.lime,
          ),
        );
      },
    );
  }

  Widget _promptArea() {
    final q = _q;
    if (q == null) {
      return Text(
        widget.spec.intro,
        textAlign: TextAlign.center,
        style:
            const TextStyle(color: AppColors.muted, fontSize: 16, height: 1.4),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (q.hint.isNotEmpty) ...[
          Text(
            q.hint.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.amber,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1),
          ),
          const SizedBox(height: 14),
        ],
        Semantics(
          label: 'Question: ${q.prompt}',
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              q.prompt,
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w700,
                color: q.promptColor ?? AppColors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _optionButton(int index) {
    final q = _q!;
    final revealed = _phase == _Phase.revealed;
    var bg = AppColors.card;
    var fg = AppColors.text;
    if (revealed && index == q.answer) {
      bg = AppColors.lime;
      fg = AppColors.bg;
    } else if (revealed && index == _picked) {
      bg = AppColors.coral;
      fg = AppColors.bg;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _phase == _Phase.asking ? () => _answer(index) : null,
        child: SizedBox(
          height: 64,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  q.options[index].label,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: fg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _options() {
    final q = _q;
    if (q == null || _phase == _Phase.matchOver) {
      return const SizedBox.shrink();
    }
    final rows = <Widget>[];
    for (var i = 0; i < q.options.length; i += 2) {
      final hasSecond = i + 1 < q.options.length;
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: Row(
            children: [
              Expanded(child: _optionButton(i)),
              if (hasSecond) ...[
                const SizedBox(width: 12),
                Expanded(child: _optionButton(i + 1)),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _bottomPanel() {
    switch (_phase) {
      case _Phase.ready:
        return FilledButton(
            onPressed: _startQuestion, child: const Text('START'));
      case _Phase.asking:
        return _hint('Pick the right answer');
      case _Phase.revealed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_revealSummary(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.4)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _next,
              child:
                  Text(_round >= widget.spec.rounds ? 'SEE RESULT' : 'NEXT'),
            ),
          ],
        );
      case _Phase.matchOver:
        final ch = widget.challenge;
        if (ch != null) {
          return ChallengeResultPanel(
            challenge: ch,
            yourScore: _youTotal,
            onBack: () {
              widget.ads?.showInterstitialIfDue();
              Navigator.of(context).pop();
            },
          );
        }
        final up = _rankedUp;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _won ? 'YOU WIN' : 'ZED WINS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: _won ? AppColors.lime : AppColors.coralSoft,
              ),
            ),
            const SizedBox(height: 6),
            Text('Your score $_youTotal  ·  Zed $_zedTotal',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            if (_newBest) ...[
              const SizedBox(height: 6),
              const Text('New personal best!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.lime, fontWeight: FontWeight.w700)),
            ],
            if (up != null) ...[
              const SizedBox(height: 6),
              Text('RANK UP: ${up.name.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.amber, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 14),
            if (!_won &&
                widget.ads != null &&
                !widget.rank.zedWeakened) ...[
              OutlinedButton.icon(
                onPressed: () => watchToWeakenZed(
                  context,
                  widget.rank,
                  widget.ads!,
                  () {
                    if (mounted) setState(() {});
                  },
                ),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Watch ad: weaken Zed next match'),
              ),
              const SizedBox(height: 10),
            ],
            if (_won) ...[
              OutlinedButton(
                onPressed: _challengeFriend,
                child: const Text('CHALLENGE A FRIEND'),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton(
              onPressed: () {
                widget.ads?.showInterstitialIfDue();
                _rematch();
              },
              child: const Text('REMATCH'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                widget.ads?.showInterstitialIfDue();
                Navigator.of(context).pop();
              },
              child: const Text('BACK TO HOME'),
            ),
          ],
        );
    }
  }

  Widget _hint(String text) {
    return SizedBox(
      height: 60,
      child: Center(
        child: Text(text,
            style: const TextStyle(color: AppColors.muted, fontSize: 15)),
      ),
    );
  }
}
