import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/rank_service.dart';
import '../../core/theme.dart';
import '../zed_ai.dart';

enum _Phase { ready, waiting, go, roundOver, matchOver }

/// Best of five: first to three round wins beats Zed.
class ReflexScreen extends StatefulWidget {
  const ReflexScreen({super.key, required this.rank});

  final RankService rank;

  @override
  State<ReflexScreen> createState() => _ReflexScreenState();
}

class _ReflexScreenState extends State<ReflexScreen> {
  static const int _maxRounds = 5;
  static const int _winsNeeded = 3;

  final ZedAi _zed = ZedAi();
  final Random _rng = Random();
  final Stopwatch _clock = Stopwatch();
  Timer? _timer;

  _Phase _phase = _Phase.ready;
  int _round = 1;
  int _youWins = 0;
  int _zedWins = 0;
  int? _yourMs;
  int? _zedMs;
  bool _falseStart = false;
  bool _matchWon = false;
  Rank? _rankedUp;
  String _taunt = ZedAi.opening;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _matchDone =>
      _youWins >= _winsNeeded || _zedWins >= _winsNeeded || _round >= _maxRounds;

  void _onTap() {
    switch (_phase) {
      case _Phase.ready:
        HapticFeedback.selectionClick();
        _startRound();
      case _Phase.waiting:
        HapticFeedback.heavyImpact();
        _timer?.cancel();
        _endRound(null);
      case _Phase.go:
        _clock.stop();
        HapticFeedback.mediumImpact();
        _endRound(_clock.elapsedMilliseconds);
      case _Phase.roundOver:
      case _Phase.matchOver:
        break;
    }
  }

  void _startRound() {
    setState(() => _phase = _Phase.waiting);
    _timer = Timer(Duration(milliseconds: 1500 + _rng.nextInt(2500)), () {
      if (!mounted) return;
      _clock
        ..reset()
        ..start();
      setState(() => _phase = _Phase.go);
    });
  }

  void _endRound(int? youMs) {
    final zedMs = _zed.nextReactionMs();
    final youWon = youMs != null && youMs < zedMs;
    if (youMs != null) _zed.learn(youMs);
    setState(() {
      _yourMs = youMs;
      _zedMs = zedMs;
      _falseStart = youMs == null;
      if (youWon) {
        _youWins++;
      } else {
        _zedWins++;
      }
      _taunt = youWon ? _zed.loseLine() : _zed.winLine();
      _phase = _Phase.roundOver;
    });
  }

  Future<void> _finishMatch() async {
    final won = _youWins > _zedWins;
    Rank? up;
    if (won) up = await widget.rank.onWinAgainstZed();
    final warmupUp = await widget.rank.onWarmupDone(DateTime.now());
    up ??= warmupUp;
    if (!mounted) return;
    setState(() {
      _matchWon = won;
      _rankedUp = up;
      _phase = _Phase.matchOver;
    });
  }

  void _nextRound() {
    if (_matchDone) {
      _finishMatch();
      return;
    }
    setState(() {
      _round++;
      _phase = _Phase.ready;
    });
  }

  void _rematch() {
    setState(() {
      _round = 1;
      _youWins = 0;
      _zedWins = 0;
      _yourMs = null;
      _zedMs = null;
      _rankedUp = null;
      _taunt = ZedAi.opening;
      _phase = _Phase.ready;
    });
  }

  static String _secs(int ms) => '${(ms / 1000).toStringAsFixed(3)}s';

  String _roundSummary() {
    if (_falseStart) return 'Too early! Zed takes the round.';
    final you = _yourMs!;
    final zed = _zedMs!;
    final base = 'You ${_secs(you)}  ·  Zed ${_secs(zed)}';
    final diff = (you - zed).abs();
    if (you > zed && diff <= 50) {
      return '$base\nLost by ${(diff / 1000).toStringAsFixed(2)}s. So close.';
    }
    return you < zed ? '$base\nYou win the round!' : '$base\nZed wins the round.';
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
              Expanded(child: Center(child: _circle())),
              _bottomPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Text('ROUND $_round / $_maxRounds',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: 'YOU $_youWins',
              style: const TextStyle(color: AppColors.lime)),
          const TextSpan(text: '  ·  '),
          TextSpan(
              text: 'ZED $_zedWins',
              style: const TextStyle(color: AppColors.coralSoft)),
        ], style: const TextStyle(fontWeight: FontWeight.w700))),
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

  Widget _circle() {
    String label;
    Color color;
    Color textColor = AppColors.bg;
    switch (_phase) {
      case _Phase.ready:
        label = 'TAP TO\nSTART';
        color = AppColors.card;
        textColor = AppColors.text;
      case _Phase.waiting:
        label = 'WAIT...';
        color = AppColors.coral;
      case _Phase.go:
        label = 'TAP!';
        color = AppColors.lime;
      case _Phase.roundOver:
        label = _falseStart ? 'TOO\nEARLY' : _secs(_yourMs!);
        color = _falseStart ? AppColors.coral : AppColors.card;
        textColor = _falseStart ? AppColors.bg : AppColors.text;
      case _Phase.matchOver:
        label = _matchWon ? 'YOU\nWIN' : 'ZED\nWINS';
        color = _matchWon ? AppColors.lime : AppColors.coral;
    }
    return Semantics(
      button: true,
      label: 'Reaction circle: $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: AppColors.line, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.w700, color: textColor),
          ),
        ),
      ),
    );
  }

  Widget _bottomPanel() {
    switch (_phase) {
      case _Phase.ready:
        return _hint('Tap the circle to start the round');
      case _Phase.waiting:
        return _hint("Wait for lime. Don't tap early!");
      case _Phase.go:
        return _hint('NOW!');
      case _Phase.roundOver:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_roundSummary(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.4)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _nextRound,
              child: Text(_matchDone ? 'SEE RESULT' : 'NEXT ROUND'),
            ),
          ],
        );
      case _Phase.matchOver:
        final up = _rankedUp;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _matchWon
                  ? 'You beat Zed $_youWins to $_zedWins!'
                  : 'Zed wins $_zedWins to $_youWins.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (up != null) ...[
              const SizedBox(height: 8),
              Text('RANK UP: ${up.name.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.amber, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _rematch, child: const Text('REMATCH')),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
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
