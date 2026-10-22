import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ads_service.dart';
import '../../core/rank_service.dart';
import '../../core/theme.dart';
import 'pattern_generator.dart';

enum _Phase { ready, asking, revealed, matchOver }

/// Five number puzzles, getting harder. Faster correct answers score more.
class PatternScreen extends StatefulWidget {
  const PatternScreen({super.key, required this.rank, this.ads});

  final RankService rank;
  final AdsService? ads;

  @override
  State<PatternScreen> createState() => _PatternScreenState();
}

class _PatternScreenState extends State<PatternScreen>
    with SingleTickerProviderStateMixin {
  static const int _rounds = 5;

  /// Chance that Zed solves each round (he gets worse as puzzles get harder).
  static const List<double> _zedAccuracy = [0.95, 0.9, 0.8, 0.65, 0.5];

  final Random _rng = Random();
  late final PatternGenerator _gen = PatternGenerator(_rng);
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  _Phase _phase = _Phase.ready;
  int _round = 1;
  PatternPuzzle? _puzzle;
  int? _picked;
  bool _timedOut = false;
  int _youTotal = 0;
  int _zedTotal = 0;
  int _gainYou = 0;
  int _gainZed = 0;
  bool _won = false;
  bool _newBest = false;
  Rank? _rankedUp;
  String _taunt = 'Patterns are my favourite. Try to keep up.';

  @override
  void initState() {
    super.initState();
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

  void _startQuestion() {
    setState(() {
      _puzzle = _gen.generate(_round);
      _picked = null;
      _timedOut = false;
      _phase = _Phase.asking;
    });
    _ctrl.forward(from: 0);
  }

  void _answer(int? option) {
    if (_phase != _Phase.asking) return;
    _ctrl.stop();
    final puzzle = _puzzle!;
    final correct = option != null && option == puzzle.answer;
    final remaining = 1 - _ctrl.value;
    final gain = correct ? 100 + (50 * remaining).round() : 0;
    final zedCorrect = _rng.nextDouble() < _zedAccuracy[_round - 1];
    final zedGain = zedCorrect ? 110 + _rng.nextInt(30) : 0;
    if (correct) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _picked = option;
      _timedOut = option == null;
      _gainYou = gain;
      _gainZed = zedGain;
      _youTotal += gain;
      _zedTotal += zedGain;
      _taunt = gain > zedGain ? 'Hm. Lucky guess.' : 'Too easy for me.';
      _phase = _Phase.revealed;
    });
  }

  void _next() {
    if (_round >= _rounds) {
      _finish();
      return;
    }
    setState(() => _round++);
    _startQuestion();
  }

  Future<void> _finish() async {
    final won = _youTotal > _zedTotal;
    Rank? up;
    final improved = _youTotal > widget.rank.patternBest;
    if (improved) {
      await widget.rank.setPatternBest(_youTotal);
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
      _puzzle = null;
      _picked = null;
      _youTotal = 0;
      _zedTotal = 0;
      _rankedUp = null;
      _newBest = false;
      _taunt = 'Patterns are my favourite. Try to keep up.';
    });
  }

  String _revealSummary() {
    final p = _puzzle!;
    final String head;
    if (_timedOut) {
      head = "Time's up!";
    } else if (_picked == p.answer) {
      head = 'Correct! +$_gainYou';
    } else {
      head = 'Not quite. Answer: ${p.answer}';
    }
    return '$head  ·  Zed +$_gainZed\n${p.rule}';
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
              const SizedBox(height: 16),
              _timerBar(),
              Expanded(child: Center(child: _sequence())),
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
              'PATTERN · ROUND $_round / $_rounds',
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

  Widget _numChip(String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? AppColors.lime : AppColors.line,
          width: 2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: highlight ? AppColors.lime : AppColors.text,
        ),
      ),
    );
  }

  Widget _sequence() {
    final p = _puzzle;
    if (p == null) {
      return const Text(
        'Find the rule. Pick the next number.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, fontSize: 16),
      );
    }
    final revealed = _phase == _Phase.revealed || _phase == _Phase.matchOver;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final n in p.shown) _numChip('$n'),
        _numChip(revealed ? '${p.answer}' : '?', highlight: true),
      ],
    );
  }

  Widget _optionButton(int value) {
    final p = _puzzle!;
    final revealed = _phase == _Phase.revealed;
    var bg = AppColors.card;
    var fg = AppColors.text;
    if (revealed && value == p.answer) {
      bg = AppColors.lime;
      fg = AppColors.bg;
    } else if (revealed && value == _picked) {
      bg = AppColors.coral;
      fg = AppColors.bg;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _phase == _Phase.asking ? () => _answer(value) : null,
        child: SizedBox(
          height: 64,
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ),
      ),
    );
  }

  Widget _options() {
    final p = _puzzle;
    if (p == null || _phase == _Phase.matchOver) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _optionButton(p.options[0])),
            const SizedBox(width: 12),
            Expanded(child: _optionButton(p.options[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _optionButton(p.options[2])),
            const SizedBox(width: 12),
            Expanded(child: _optionButton(p.options[3])),
          ],
        ),
      ],
    );
  }

  Widget _bottomPanel() {
    switch (_phase) {
      case _Phase.ready:
        return FilledButton(
            onPressed: _startQuestion, child: const Text('START'));
      case _Phase.asking:
        return _hint('Pick the next number');
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
