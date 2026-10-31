/// A goal that resets every Monday. Finishing it pays rank points once.
class WeeklyGoal {
  const WeeklyGoal({
    required this.id,
    required this.title,
    required this.target,
    required this.reward,
  });

  final String id;
  final String title;
  final int target;
  final int reward;
}

const List<WeeklyGoal> weeklyGoals = [
  WeeklyGoal(
    id: 'wins10',
    title: 'Win 10 matches against Zed',
    target: 10,
    reward: 30,
  ),
  WeeklyGoal(
    id: 'all_games',
    title: 'Beat Zed in 4 different games',
    target: 4,
    reward: 30,
  ),
  WeeklyGoal(
    id: 'gauntlet3',
    title: 'Finish the Daily Gauntlet on 3 days',
    target: 3,
    reward: 40,
  ),
];
