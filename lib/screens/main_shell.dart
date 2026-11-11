import 'package:flutter/material.dart';

import '../core/ads_service.dart';
import '../core/rank_service.dart';
import '../core/reminder_service.dart';
import '../core/theme.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

/// The app's root: Play, Progress and Settings behind a bottom navigation bar.
/// Games and the Gauntlet are still pushed on top, full screen.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.rank,
    this.ads,
    this.reminders,
  });

  final RankService rank;
  final AdsService? ads;
  final ReminderService? reminders;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final ValueNotifier<int> _homeRefresh = ValueNotifier<int>(0);
  int _index = 0;

  @override
  void dispose() {
    _homeRefresh.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    // Coming back to Play: redraw it with anything changed elsewhere.
    if (i == 0) _homeRefresh.value++;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // On Progress or Settings, Back returns to Play instead of leaving.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            HomeScreen(
              rank: widget.rank,
              ads: widget.ads,
              reminders: widget.reminders,
              onOpenProgress: () => _select(1),
              onOpenSettings: () => _select(2),
              refresh: _homeRefresh,
            ),
            // Built only while visible, so they always show fresh numbers.
            if (_index == 1)
              ProgressScreen(rank: widget.rank, ads: widget.ads, embedded: true)
            else
              const SizedBox.shrink(),
            if (_index == 2)
              SettingsScreen(
                rank: widget.rank,
                ads: widget.ads,
                reminders: widget.reminders,
                embedded: true,
              )
            else
              const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: const Color(0xFF141A3C),
            indicatorColor: const Color(0x33B8F34A),
            iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? AppColors.lime
                    : AppColors.muted,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
              (states) => TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: states.contains(WidgetState.selected)
                    ? AppColors.lime
                    : AppColors.muted,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.sports_esports_rounded),
                label: 'Play',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_rounded),
                label: 'Progress',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
