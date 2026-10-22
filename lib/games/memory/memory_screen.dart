import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ads_service.dart';
import '../../core/rank_service.dart';
import '../../core/theme.dart';

enum _Phase { intro, showing, input, between, matchOver }

/// Watch the tiles light up, then repeat the order.
/// Zed "holds" a fixed number of tiles; hold more than him to win.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key, required this.rank, this.ads});

  final RankService rank;
  final AdsService? ads;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  static const int _tiles = 9;
  static const int _startLen = 3;
  static const int _maxLives = 3;

  final Random _rng = Random();
  int _attempt = 0;
  late int _zedCap;
  String _taunt = '';

  _Phase _phase = _Phase.intro;
  int _len = _startLen;
  int _bestCleared = 0;
  int _lives = _maxLives;
  List<int> _sequence = [];
  int _inputIndex = 0;
  int? _lit;
  int? _wrong;
  int _run = 0; // bumped to cancel any running animation
  bool _won = false;
  bool _newBest = false;
  Rank? _rankedUp;

  @override
  void initState() {
    super.initState();
    _pickZed();
  }

  @override
  void dispose() {
    _run++;
    super.dispose();
  }

  /// Same Zed capacity for everyone on the same day (plus rematch number).
  void _pickZed() {
    final seed = DailyTwist.seedForDate(DateTime.now()) * 31 + _attempt;
    _zedCap = 6 + Random(seed).nextInt(3);
    _taunt = 'I hold $_zedCap tiles. Show me you can hold more.';
  }

  Future<void> _startLevel() async {
    final run = ++_run;
    final seq = <int>[];
    for (var i = 0; i < _len; i++) {
      var t = _rng.nextInt(_tiles);
      while (i > 0 && t == seq[i - 1]) {
        t = _rng.nextInt(_tiles);
      }
      seq.add(t);
    }
    setState(() {
      _sequence = seq;
      _inputIndex = 0;
      _wrong = null;
      _lit = null;
      _phase = _Phase.showing;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    for (final t in seq) {
      if (!mounted || run != _run) return;
      setState(() => _lit = t);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted || run != _run) return;
      setState(() => _lit = null);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted || run != _run) return;
    setState(() => _phase = _Phase.input);
  }

  void _onTile(int i) {
    if (_phase != _Phase.input) return;
    if (i == _sequence[_inputIndex]) {
      HapticFeedback.selectionClick();
      setState(() {
        _lit = i;
        _inputIndex++;
      });
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _lit = null);
      });
      if (_inputIndex >= _len) _levelCleared();
    } else {
      HapticFeedback.heavyImpact();
      _wrongTap(i);
    }
  }

  Future<void> _levelCleared() async {
    final run = ++_run;
    final cleared = _len;
    if (cleared > _bestCleared) _bestCleared = cleared;
    // Lock input immediately so a fast extra tap cannot run past the sequence.
    setState(() => _phase = _Phase.between);
    if (cleared > _zedCap) {
      await _finishMatch(won: true);
      return;
    }
    setState(() {
      _phase = _Phase.between;
      _taunt = 'Hm. $cleared tiles. Lucky.';
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || run != _run) return;
    setState(() => _len++);
    _startLevel();
  }

  Future<void> _wrongTap(int i) async {
    final run = ++_run;
    _lives--;
    setState(() {
      _wrong = i;
      _phase = _Phase.between;
      _taunt = 'Forgot already?';
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || run != _run) return;
    if (_lives <= 0) {
      await _finishMatch(won: false);
      return;
    }
    _startLevel();
  }

  Future<void> _finishMatch({required bool won}) async {
    Rank? up;
    final improved = _bestCleared > widget.rank.memoryBest;
    if (improved) {
      await widget.rank.setMemoryBest(_bestCleared);
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
    _run++;
    _attempt++;
    _pickZed();
    setState(() {
      _phase = _Phase.intro;
      _len = _startLen;
      _bestCleared = 0;
      _lives = _maxLives;
      _sequence = [];
      _inputIndex = 0;
      _lit = null;
      _wrong = null;
      _rankedUp = null;
      _newBest = false;
    });
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
              Expanded(child: Center(child: _grid())),
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
              'MEMORY · $_len TILES',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Semantics(
          label: 'Lives left: $_lives',
          child: Row(
            children: List.generate(
              _maxLives,
              (i) => Icon(
                i < _lives ? Icons.favorite : Icons.favorite_border,
                color: AppColors.coralSoft,
                size: 22,
              ),
            ),
          ),
        ),
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

  Widget _grid() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(_tiles, _tile),
        ),
      ),
    );
  }

  Widget _tile(int i) {
    var color = AppColors.card;
    if (_lit == i) color = AppColors.lime;
    if (_wrong == i) color = AppColors.coral;
    return Semantics(
      button: true,
      label: 'Tile ${i + 1}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onTile(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _bottomPanel() {
    switch (_phase) {
      case _Phase.intro:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Watch the tiles light up, then repeat the order.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 15),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _startLevel, child: const Text('START')),
          ],
        );
      case _Phase.showing:
        return _hint('Watch the pattern...');
      case _Phase.input:
        return _hint('Your turn · $_inputIndex of $_len');
      case _Phase.between:
        return _hint(_wrong != null
            ? 'Wrong tile! $_lives ${_lives == 1 ? 'life' : 'lives'} left'
            : 'Nice! Next level...');
      case _Phase.matchOver:
        final up = _rankedUp;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _won
                  ? 'You held $_bestCleared tiles. Zed holds $_zedCap. You win!'
                  : 'You held $_bestCleared tiles. Zed holds $_zedCap.',
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
