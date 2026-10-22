import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ads_service.dart';
import '../../core/rank_service.dart';
import '../../core/theme.dart';

enum _Phase { ready, playing, roundOver, matchOver }

/// A marker sweeps across a bar. Tap when it is inside the green zone.
/// Five rounds, the sweep gets faster each round. Highest average wins.
class PrecisionScreen extends StatefulWidget {
  const PrecisionScreen({super.key, required this.rank, this.ads});

  final RankService rank;
  final AdsService? ads;

  @override
  State<PrecisionScreen> createState() => _PrecisionScreenState();
}

/// Zed's accuracy: stays close to your recent average, with some wobble.
class _ZedAccuracy {
  final Random _rng = Random();
  double? _avg;

  int next() {
    final avg = _avg;
    final base = avg == null ? 86.0 : (avg * 0.97).clamp(70.0, 96.0);
    final jitter = (_rng.nextDouble() - 0.5) * 14;
    return (base + jitter).clamp(55.0, 99.0).round();
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
  static const double _zoneFrac = 0.12;

  final Random _rng = Random();
  final _ZedAccuracy _zed = _ZedAccuracy();
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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int _avg(List<int> l) =>
      l.isEmpty ? 0 : (l.reduce((a, b) => a + b) / l.length).round();

  void _beginRound() {
    final ms = 1500 - (_round - 1) * 150;
    _target = 0.15 + _rng.nextDouble() * 0.7;
    _ctrl.duration = Duration(milliseconds: ms);
    _ctrl.repeat(reverse: true);
    setState(() => _phase = _Phase.playing);
  }

  void _onTap() {
    if (_phase != _Phase.playing) return;
    _ctrl.stop();
    HapticFeedback.mediumImpact();
    final err = (_ctrl.value - _target).abs();
    final acc = (100 * (1 - err / 0.4)).clamp(0.0, 100.0).round();
    final zedAcc = _zed.next();
    _zed.learn(acc);
    setState(() {
      _you.add(acc);
      _zedScores.add(zedAcc);
      _lastYou = acc;
      _lastZed = zedAcc;
      _taunt = acc >= zedAcc ? 'A lucky hand. Again.' : 'Not even close.';
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
      _newBest = improved;
      _rankedUp = up;
      _phase = _Phase.matchOver;
    });
  }

  void _rematch() {
    _ctrl.stop();
    setState(() {
      _phase = _Phase.ready;
      _round = 1;
      _you.clear();
      _zedScores.clear();
      _rankedUp = null;
      _newBest = false;
      _taunt = 'Steady hands? I doubt it.';
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
      child: Text('ZED-9: "$_taunt"', style: const TextStyle(fontSize: 16)),
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
