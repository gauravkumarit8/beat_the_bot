import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/rank_service.dart';
import '../core/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.rank});

  final RankService rank;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _appVersion = '0.1.0';

  Future<void> _setVibration(bool on) async {
    await widget.rank.setVibration(on);
    Haptics.enabled = on;
    Haptics.medium();
    if (mounted) setState(() {});
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Reset progress?'),
        content: const Text(
          'Your rank, streak, personal bests and difficulty learning will be '
          'erased. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('RESET',
                style: TextStyle(color: AppColors.coralSoft)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.rank.resetProgress();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress reset.')),
    );
  }

  void _showPrivacy() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Privacy'),
        content: const Text(
          'Your rank, streak and scores are stored only on this phone, and '
          'the game works offline. Ads are shown by Google AdMob, which may '
          "use your device's advertising ID to choose ads.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const Text('Settings',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SwitchListTile(
                value: widget.rank.vibrationOn,
                onChanged: _setVibration,
                title: const Text('Vibration'),
                subtitle: const Text('Feedback on taps and results',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Privacy'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.muted),
                    onTap: _showPrivacy,
                  ),
                  const Divider(height: 1, color: AppColors.line),
                  ListTile(
                    title: const Text('Reset progress',
                        style: TextStyle(color: AppColors.coralSoft)),
                    subtitle: const Text('Erase rank, streak and best scores',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    onTap: _confirmReset,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text('Beat the Bot · version $_appVersion',
                  style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
