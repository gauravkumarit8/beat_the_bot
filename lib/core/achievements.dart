import 'rank_service.dart';

/// One badge the player can unlock. [isMet] reads the saved progress.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.isMet,
  });

  final String id;
  final String title;
  final String description;
  final bool Function(RankService r) isMet;
}

final List<Achievement> allAchievements = [
  Achievement(
    id: 'first_win',
    title: 'First blood',
    description: 'Beat Zed once.',
    isMet: (r) => r.totalWins >= 1,
  ),
  Achievement(
    id: 'wins_25',
    title: 'Zed hunter',
    description: 'Beat Zed 25 times.',
    isMet: (r) => r.totalWins >= 25,
  ),
  Achievement(
    id: 'hard_win',
    title: 'No mercy',
    description: 'Beat Zed on Hard.',
    isMet: (r) => r.hardWins >= 1,
  ),
  Achievement(
    id: 'streak_3',
    title: 'On a roll',
    description: 'Reach a 3-day streak.',
    isMet: (r) => r.bestStreak >= 3,
  ),
  Achievement(
    id: 'streak_7',
    title: 'Week warrior',
    description: 'Reach a 7-day streak.',
    isMet: (r) => r.bestStreak >= 7,
  ),
  Achievement(
    id: 'streak_30',
    title: 'Unstoppable',
    description: 'Reach a 30-day streak.',
    isMet: (r) => r.bestStreak >= 30,
  ),
  Achievement(
    id: 'rank_sharp',
    title: 'Getting sharp',
    description: 'Reach the Sharp rank.',
    isMet: (r) => r.highestRankIndex >= Rank.sharp.index,
  ),
  Achievement(
    id: 'rank_elite',
    title: 'Elite mind',
    description: 'Reach the Elite rank.',
    isMet: (r) => r.highestRankIndex >= Rank.elite.index,
  ),
  Achievement(
    id: 'rank_legend',
    title: 'Legend',
    description: 'Reach the Legend rank.',
    isMet: (r) => r.highestRankIndex >= Rank.legend.index,
  ),
  Achievement(
    id: 'gauntlet_1',
    title: 'Gauntlet runner',
    description: 'Finish a Daily Gauntlet.',
    isMet: (r) => r.gauntletBest > 0,
  ),
  Achievement(
    id: 'gauntlet_800',
    title: 'Gauntlet ace',
    description: 'Score 800 or more in a Gauntlet.',
    isMet: (r) => r.gauntletBest >= 800,
  ),
  Achievement(
    id: 'perfect',
    title: 'Clean sweep',
    description: 'Beat Zed in all four Gauntlet games.',
    isMet: (r) => r.perfectGauntlets >= 1,
  ),
  Achievement(
    id: 'challenger',
    title: 'Challenger',
    description: "Play a friend's challenge code.",
    isMet: (r) => r.challengesPlayed >= 1,
  ),
  Achievement(
    id: 'rival_beaten',
    title: 'Friendly fire',
    description: "Beat a friend's challenge score.",
    isMet: (r) => r.challengesWon >= 1,
  ),
  Achievement(
    id: 'rival_5',
    title: 'Local legend',
    description: "Beat 5 friends' challenge scores.",
    isMet: (r) => r.challengesWon >= 5,
  ),
  Achievement(
    id: 'reflex_250',
    title: 'Lightning',
    description: 'React in under 250 ms.',
    isMet: (r) => r.reflexBestMs > 0 && r.reflexBestMs < 250,
  ),
  Achievement(
    id: 'memory_9',
    title: 'Elephant',
    description: 'Hold 9 tiles in Memory.',
    isMet: (r) => r.memoryBest >= 9,
  ),
  Achievement(
    id: 'precision_95',
    title: 'Steady hands',
    description: 'Average 95% in Precision.',
    isMet: (r) => r.precisionBest >= 95,
  ),
  Achievement(
    id: 'math_1000',
    title: 'Human calculator',
    description: 'Score 1000 or more in Math Rush.',
    isMet: (r) => r.quizBest('math') >= 1000,
  ),
  Achievement(
    id: 'color_1000',
    title: 'Eagle eye',
    description: 'Score 1000 or more in Color Clash.',
    isMet: (r) => r.quizBest('color') >= 1000,
  ),
  Achievement(
    id: 'pattern_600',
    title: 'Pattern master',
    description: 'Score 600 or more in Pattern.',
    isMet: (r) => r.patternBest >= 600,
  ),
];
