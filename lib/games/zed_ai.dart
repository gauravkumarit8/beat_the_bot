import 'dart:math';

import '../core/difficulty.dart';

/// Zed's reaction-time brain. He learns your average and stays just beatable.
class ZedAi {
  ZedAi({this.level = Level.medium, this.handicap = 1.0});

  final Level level;

  /// 1.0 is normal. Above 1.0 Zed reacts slower (after a rewarded ad).
  final double handicap;

  static const String opening = 'Think you can beat me?';

  final Random _rng = Random();
  double? _avgMs;

  /// Call after every valid player reaction.
  void learn(int playerMs) {
    final avg = _avgMs;
    _avgMs = avg == null ? playerMs.toDouble() : avg * 0.7 + playerMs * 0.3;
  }

  /// Zed aims to be about 3% faster than you, with a little randomness.
  int nextReactionMs() {
    final avg = _avgMs;
    final start = switch (level) {
      Level.easy => 330.0,
      Level.medium => 280.0,
      Level.hard => 240.0,
    };
    final factor = switch (level) {
      Level.easy => 1.12,
      Level.medium => 0.97,
      Level.hard => 0.90,
    };
    final base = (avg == null ? start : avg * factor) * handicap;
    final jitter = (_rng.nextDouble() - 0.5) * 80;
    return (base + jitter).clamp(190.0, 420.0).round();
  }

  static const List<String> _zedWinsLines = [
    'Too slow, human.',
    'Blink and you miss it.',
    'Is that all you have?',
    'Predictable.',
    'Is your thumb even awake?',
    'I have seen faster toasters.',
    'Losing builds character. You are very well built.',
    'Do not worry. I will go easy. No I will not.',
  ];

  static const List<String> _youWinLines = [
    'Lucky. Do not get used to it.',
    'Hm. Fine. Again.',
    'My sensors were calibrating.',
    'You will not do that twice.',
    'Enjoy it. It will not last.',
    'A glitch. That was a glitch.',
    'Now I am taking this personally.',
    'Do that again. I dare you.',
  ];

  String winLine() => _zedWinsLines[_rng.nextInt(_zedWinsLines.length)];

  String loseLine() => _youWinLines[_rng.nextInt(_youWinLines.length)];
}
