import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/ad_actions.dart';
import '../../core/ads_service.dart';
import '../../core/brag.dart';
import '../../core/challenge.dart';
import '../../core/difficulty.dart';
import '../../core/haptics.dart';
import '../../core/game_result.dart';
import '../../core/rank_service.dart';
import '../../core/theme.dart';
import '../../core/zed_voice.dart';
import '../../widgets/challenge_panel.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/zed_face.dart';

enum _Phase { ready, playing, roundOver, matchOver }

/// A marker sweeps across a bar. Tap when it is inside the green zone.
/// Five rounds, the sweep gets faster each round. Highest average wins.
class PrecisionScreen extends StatefulWidget {
  const PrecisionScreen({
    super.key,
    required this.rank,
    this.ads,
    this.gauntlet = false,
    this.seed,
    this.challenge,
  });

  final RankService rank;
  final AdsService? ads;

  /// When true, the game hands its result back instead of paying rewards.
  final bool gauntlet;

  /// Same seed gives the same target positions (Daily Gauntlet).
  final int? seed;

  /// A friend's challenge to beat. Replays their seed and level.
  final Challenge? challenge;

  @override
  State<PrecisionScreen> createState() => _PrecisionScreenState();
}

/// Zed's accuracy: stays close to your recent average, with some wobble.
class _ZedAccuracy {
  _ZedAccuracy(this.level, {this.penalty = 0});

  final Level level;

  /// Points taken off Zed's accuracy (after a rewarded ad).
  final double penalty;
  final Random _rng = Random();
  double? _avg;

  int next() {
    final avg = _avg;
    final start = switch (level) {
      Level.easy => 80.0,
      Level.medium => 86.0,
      Level.hard => 92.0,
    };
    final factor = switch (level) {
      Level.easy => 0.92,
      Level.medium => 0.97,
      Level.hard => 1.0,
    };
    final base = avg == null ? start : (avg * factor).clamp(70.0, 98.0);
    final jitter = (_rng.nextDouble() - 0.5) * 14;
    return (base + jitter - penalty).clamp(55.0, 99.0).round();
  }

  void learn(int playerAccuracy) {
    final avg = _avg;
    _avg = avg == null
        ? playerAccuracy.toDouble()
        : avg * 0.7 + playerAccuracy * 0.3;
  }
}

class _PrecisionScreenState extends State<PrecisionScreen>
    with SingleTickerProviderStateMixin {
  static const int _rounds = 5;

  late Level _level;
  bool _weak = false;

  /// Width of the green zone as a fraction of the bar.
  double get _zoneFrac => switch (_level) {
        Level.easy => 0.16,
        Level.medium => 0.12,
        Level.hard => 0.08,
      };

  /// How far from the centre (as a fraction of the bar) scores 0%.
  double get _errScale => switch (_level) {
        Level.easy => 0.5,
        Level.medium => 0.4,
        Level.hard => 0.3,
      };

  int get _startMs => switch (_level) {
        Level.easy => 1800,
        Level.medium => 1500,
        Level.hard => 1200,
      };
  int get _stepMs => switch (_level) {
        Level.easy => 150,
        Level.medium => 150,
        Level.hard => 120,
      };

  late int _matchSeed;
  late _ZedAccuracy _zed;
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  _Phase _phase = _Phase.ready;
  int _round = 1;
  double _target = 0.5;
  final List<int> _you = [];
  final List<int> _zedScores = [];
  int _lastYou = 0;
  int _lastZed = 0;
  bool _won = false;
  bool _newBest = false;
  Rank? _rankedUp;
  String _taunt = 'Steady hands? I doubt it.';
  ZedMood _mood = ZedMood.neutral;

  @override
  void initState() {
    super.initState();
    _level = widget.challenge?.level ?? widget.rank.levelFor('precision');
    _reseed();
    _weak = widget.rank.zedWeakened;
    if (_weak) widget.rank.setZedWeakened(false);
    _zed = _ZedAccuracy(_level, penalty: _weak ? 8 : 0);
    final c = widget.challenge;
    if (c != null) _taunt = 'Your friend averaged ${c.score}%. Beat that.';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int _avg(List<int> l) =>
      l.isEmpty ? 0 : (l.reduce((a, b) => a + b) / l.length).round();

  void _reseed() {
    _matchSeed =
        widget.challenge?.seed ?? widget.seed ?? Random().nextInt(1 << 24);
  }

  void _beginRound() {
    final ms = _startMs - (_round - 1) * _stepMs;
    // Same seed and round always give the same target (challenge codes).
    _target = 0.15 + Random(_matchSeed * 100 + _round).nextDouble() * 0.7;
    _ctrl.duration = Duration(milliseconds: ms);
    _ctrl.repeat(reverse: true);
    setState(() => _phase = _Phase.playing);
  }

  void _onTap() {
    if (_phase != _Phase.playing) return;
    _ctrl.stop();
    Haptics.medium();
    final err = (_ctrl.value - _target).abs();
    final acc = (100 * (1 - err / _errScale)).clamp(0.0, 100.0).round();
    final zedAcc = _zed.next();
    _zed.learn(acc);
    setState(() {
      _you.add(acc);
      _zedScores.add(zedAcc);
      _lastYou = acc;
      _lastZed = zedAcc;
      _taunt = acc >= zedAcc ? 'A lucky hand. Again.' : 'Not even close.';
      _mood = acc >= zedAcc ? ZedMood.annoyed : ZedMood.smug;
      _phase = _Phase.roundOver;
    });
  }

  void _next() {
    if (_round >= _rounds) {
      _finish();
      return;
    }
    setState(() => _round++);
    _beginRound();
  }

  Future<void> _finish() async {
    final you = _avg(_you);
    final zed = _avg(_zedScores);
    final won = you > zed;
    final challenge = widget.challenge;
    if (challenge != null) {
      final beat = you > challenge.score;
      await widget.rank.recordChallenge(beat);
      if (!mounted) return;
      setState(() {
        _won = beat;
        _mood = beat ? ZedMood.shocked : ZedMood.smug;
        _phase = _Phase.matchOver;
      });
      return;
    }
    await widget.rank.recordResult('precision', _level, won);
    if (widget.gauntlet) {
      if (!mounted) return;
      setState(() {
        _won = won;
        _mood = won ? ZedMood.shocked : ZedMood.smug;
        _phase = _Phase.matchOver;
      });
      return;
    }
    Rank? up;
    final improved = you > widget.rank.precisionBest;
    if (improved) {
      await widget.rank.setPrecisionBest(you);
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
    _level = widget.challenge?.level ?? widget.rank.levelFor('precision');
    _reseed();
    _weak = widget.rank.zedWeakened;
    if (_weak) widget.rank.setZedWeakened(false);
    _zed = _ZedAccuracy(_level, penalty: _weak ? 8 : 0);
    setState(() {
      _phase = _Phase.ready;
      _round = 1;
      _you.clear();
      _zedScores.clear();
      _rankedUp = null;
      _newBest = false;
      _taunt = 'Steady hands? I doubt it.';
      _mood = ZedMood.neutral;
    });
  }

  String _roundSummary() {
    final head = 'You $_lastYou%  ·  Zed $_lastZed%';
    final gap = _lastZed - _lastYou;
    if (gap > 0 && gap <= 3) {
      return '$head\nLost by $gap points. So close.';
    }
    final verdict =
        _lastYou > _lastZed ? 'You win the round!' : 'Zed wins the round.';
    return '$head\n$verdict';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              _badge(),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _onTap(),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _bar(),
                        const SizedBox(height: 28),
                        _bigText(),
                      ],
                    ),
                  ),
                ),
              ),
              _bottomPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge() => DifficultyBadge(
        level: _level,
        auto: widget.challenge == null &&
            widget.rank.difficulty == Difficulty.auto,
      );

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
              'PRECISION · ROUND $_round / $_rounds',
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

  Widget _bar() {
    return Semantics(
      label: 'Precision bar. Tap when the marker is in the green zone.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final zoneW = w * _zoneFrac;
          const markW = 8.0;
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return SizedBox(
                height: 64,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line, width: 2),
                      ),
                    ),
                    Positioned(
                      left: _target * w - zoneW / 2,
                      width: zoneW,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x59B8F34A),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.lime, width: 2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _ctrl.value * w - markW / 2,
                      width: markW,
                      top: -6,
                      bottom: -6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.text,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _bigText() {
    switch (_phase) {
      case _Phase.ready:
        return const Text(
          'Tap when the marker is inside the green zone',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 16),
        );
      case _Phase.playing:
        return const Text('TAP!',
            style: TextStyle(
                color: AppColors.lime, fontSize: 44, fontWeight: FontWeight.w700));
      case _Phase.roundOver:
        return Text('$_lastYou%',
            style:
                const TextStyle(fontSize: 56, fontWeight: FontWeight.w700));
      case _Phase.matchOver:
        return Text(
          _won ? 'YOU WIN' : 'ZED WINS',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: _won ? AppColors.lime : AppColors.coralSoft,
          ),
        );
    }
  }

  Widget _bottomPanel() {
    switch (_phase) {
      case _Phase.ready:
        return FilledButton(
            onPressed: _beginRound, child: const Text('START'));
      case _Phase.playing:
        return _hint('Tap anywhere to lock in');
      case _Phase.roundOver:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_roundSummary(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.4)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _next,
              child: Text(_round >= _rounds ? 'SEE RESULT' : 'NEXT ROUND'),
            ),
          ],
        );
      case _Phase.matchOver:
        final ch = widget.challenge;
        if (ch != null) {
          return ChallengeResultPanel(
            challenge: ch,
            yourScore: _avg(_you),
            onBack: () {
              widget.ads?.showInterstitialIfDue();
              Navigator.of(context).pop();
            },
          );
        }
        if (widget.gauntlet) return _gauntletPanel();
        final up = _rankedUp;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your average ${_avg(_you)}%  ·  Zed ${_avg(_zedScores)}%',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
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
            const SizedBox(height: 16),
            if (!_won && widget.ads != null && !widget.rank.zedWeakened) ...[
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

  GameResult _result() => GameResult(
        game: 'Precision',
        won: _won,
        score: _avg(_you) * 2 + (_won ? 50 : 0),
      );

  Widget _gauntletPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your average ${_avg(_you)}%  ·  Zed ${_avg(_zedScores)}%',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_result()),
          child: const Text('CONTINUE'),
        ),
      ],
    );
  }

  void _challengeFriend() => copyBrag(
        context,
        Challenge(
          game: 'precision',
          level: _level,
          seed: _matchSeed,
          score: _avg(_you),
        ).shareText,
      );

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
