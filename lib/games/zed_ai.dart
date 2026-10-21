import 'dart:math';

/// Zed's reaction-time brain. He learns your average and stays just beatable.
class ZedAi {
  ZedAi();

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
    final base = avg == null ? 280.0 : avg * 0.97;
    final jitter = (_rng.nextDouble() - 0.5) * 80;
    return (base + jitter).clamp(190.0, 420.0).round();
  }

  static const List<String> _zedWinsLines = [
    'Too slow, human.',
    'Blink and you miss it.',
    'Is that all you have?',
    'Predictable.',
  ];

  static const List<String> _youWinLines = [
    'Lucky. Do not get used to it.',
    'Hm. Fine. Again.',
    'My sensors were calibrating.',
    'You will not do that twice.',
  ];

  String winLine() => _zedWinsLines[_rng.nextInt(_zedWinsLines.length)];

  String loseLine() => _youWinLines[_rng.nextInt(_youWinLines.length)];
}
