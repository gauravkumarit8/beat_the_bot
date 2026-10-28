import 'package:flutter/painting.dart';

/// A colour scheme for Zed's face. Skins are unlocked by achievements,
/// never bought.
class ZedSkin {
  const ZedSkin({
    required this.id,
    required this.name,
    required this.head,
    required this.outline,
    required this.eyes,
    this.unlockedBy,
    this.hint = '',
  });

  final String id;
  final String name;
  final Color head;
  final Color outline;
  final Color eyes;

  /// Id of the achievement that unlocks this skin, or null if always unlocked.
  final String? unlockedBy;
  final String hint;
}

class ZedSkins {
  static const List<ZedSkin> all = [
    ZedSkin(
      id: 'classic',
      name: 'Classic',
      head: Color(0xFF232C55),
      outline: Color(0xFFB8F34A),
      eyes: Color(0xFFFF6B5B),
    ),
    ZedSkin(
      id: 'ice',
      name: 'Ice',
      head: Color(0xFF1B3A5C),
      outline: Color(0xFF5BD6FF),
      eyes: Color(0xFF9CE8FF),
      unlockedBy: 'streak_7',
      hint: 'Reach a 7-day streak.',
    ),
    ZedSkin(
      id: 'gold',
      name: 'Gold',
      head: Color(0xFF3A2F12),
      outline: Color(0xFFFFB547),
      eyes: Color(0xFFFFD75E),
      unlockedBy: 'rank_elite',
      hint: 'Reach the Elite rank.',
    ),
    ZedSkin(
      id: 'neon',
      name: 'Neon',
      head: Color(0xFF2A1240),
      outline: Color(0xFFFF4FD8),
      eyes: Color(0xFFFF4FD8),
      unlockedBy: 'gauntlet_800',
      hint: 'Score 800 or more in a Gauntlet.',
    ),
    ZedSkin(
      id: 'shadow',
      name: 'Shadow',
      head: Color(0xFF0B0E1A),
      outline: Color(0xFFF2F5FF),
      eyes: Color(0xFFFF3B3B),
      unlockedBy: 'hard_win',
      hint: 'Beat Zed on Hard.',
    ),
    ZedSkin(
      id: 'legend',
      name: 'Legend',
      head: Color(0xFF2A2060),
      outline: Color(0xFFB07CFF),
      eyes: Color(0xFFFFE066),
      unlockedBy: 'rank_legend',
      hint: 'Reach the Legend rank.',
    ),
  ];

  /// The skin used by every Zed face in the app right now.
  static ZedSkin current = all.first;

  static ZedSkin byId(String? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);
}
