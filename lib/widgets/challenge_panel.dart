import 'package:flutter/material.dart';

import '../core/brag.dart';
import '../core/challenge.dart';
import '../core/theme.dart';

/// Result of playing a friend's challenge code.
class ChallengeResultPanel extends StatelessWidget {
  const ChallengeResultPanel({
    super.key,
    required this.challenge,
    required this.yourScore,
    required this.onBack,
  });

  final Challenge challenge;
  final int yourScore;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final diff = yourScore - challenge.score;
    final String verdict;
    final Color color;
    if (diff > 0) {
      verdict = 'YOU BEAT YOUR FRIEND';
      color = AppColors.lime;
    } else if (diff == 0) {
      verdict = 'A TIE';
      color = AppColors.amber;
    } else {
      verdict = 'YOUR FRIEND WINS';
      color = AppColors.coralSoft;
    }
    final back = Challenge(
      game: challenge.game,
      level: challenge.level,
      seed: challenge.seed,
      score: yourScore,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          verdict,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        Text(
          'Friend ${challenge.scoreLabel(challenge.score)}  ·  '
          'You ${challenge.scoreLabel(yourScore)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => copyBrag(context, back.shareText),
          child: const Text('CHALLENGE BACK'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onBack, child: const Text('BACK TO HOME')),
      ],
    );
  }
}
