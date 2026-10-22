import 'package:flutter/material.dart';

import '../core/difficulty.dart';
import '../core/theme.dart';

/// Small line under Zed's taunt showing the level this match is played at.
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({super.key, required this.level, required this.auto});

  final Level level;
  final bool auto;

  @override
  Widget build(BuildContext context) {
    final text = auto
        ? '${level.label.toUpperCase()} · AUTO'
        : level.label.toUpperCase();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.tune_rounded, size: 14, color: AppColors.muted),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
              color: AppColors.muted, fontSize: 12, letterSpacing: 1),
        ),
      ],
    );
  }
}
