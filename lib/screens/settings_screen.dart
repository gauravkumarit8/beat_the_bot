import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';

import '../core/ads_service.dart';
import '../core/error_log.dart';
import '../core/fx.dart';
import '../core/haptics.dart';
import '../core/rank_service.dart';
import '../core/sfx.dart';
import '../core/reminder_service.dart';
import '../core/theme.dart';
import '../games/quiz/quiz_specs.dart';
import '../widgets/fx_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.rank,
    this.ads,
    this.reminders,
    this.embedded = false,
  });

  /// True when shown as a bottom-navigation tab (no Back button).
  final bool embedded;

  final RankService rank;
  final AdsService? ads;
  final ReminderService? reminders;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _appVersion = '0.1.0';

  /// Change this to wherever you host the privacy policy page.
  static const String _policyUrl =
      'https://gauravkumarit8.github.io/beat-the-bot/privacy/';

  bool _adChoices = false;

  @override
  void initState() {
    super.initState();
    _checkAdChoices();
  }

  Future<void> _checkAdChoices() async {
    final ads = widget.ads;
    if (ads == null) return;
    final needed = await ads.privacyOptionsRequired();
    if (mounted) setState(() => _adChoices = needed);
  }

  static const String _howText =
      'RANK. Win matches to earn rank points (RP) and climb from Rookie to Legend. '
      'Miss days and you slowly lose points, after one free grace day.\n\n'
      'DAILY CHEST. Play a match, beat Zed\'s dare and finish the Daily Gauntlet. '
      'Then open the chest for RP, and sometimes a streak freeze.\n\n'
      'ZED\'S DARE. One game a day. Beat Zed in it for bonus RP.\n\n'
      'ZED\'S TWIST. A rule change for the quiz games each day, like less time '
      'or extra questions. Your first win under it pays a bonus.\n\n'
      'WEEKLY BOSS. Every win hurts the boss: Easy 5, Medium 10, Hard 15, '
      'doubled at the weekend. Defeat it for RP and a freeze.\n\n'
      'DAILY GAUNTLET. Six games, one score out of 1000, the same puzzles for '
      'everyone today. Beat Zed in 4 of 6.\n\n'
      'ZED STREAK. Beat Zed in the Gauntlet every day. Only your first two runs '
      'each day count. Every 7th day earns a shield that saves one missed day.\n\n'
      'STREAK FREEZE. Protects your daily streak for one missed day.\n\n'
      'CHALLENGE A FRIEND. After a win, share the code. Your friend enters it '
      'from Home to play the same puzzles.';

  Future<void> _howItWorks() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How it works'),
        content: const SingleChildScrollView(
          child: Text(_howText, style: TextStyle(height: 1.45)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  Future<void> _reportProblem() async {
    await Clipboard.setData(ClipboardData(text: ErrorLog.report()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied. Paste it in a message to the developer.'),
      ),
    );
  }

  int _titleTaps = 0;
  bool _insights = false;

  Future<void> _setColorBlindHelp(bool on) async {
    await widget.rank.setColorBlindHelp(on);
    ColorClashSpec.markers = on;
    if (mounted) setState(() {});
  }

  Future<void> _setReduceFx(bool on) async {
    await widget.rank.setReduceEffects(on);
    Fx.animations = !on;
    if (mounted) setState(() {});
  }

  Future<void> _setSound(bool on) async {
    await widget.rank.setSound(on);
    Sfx.enabled = on;
    if (on) Sfx.play(Sound.correct);
    if (mounted) setState(() {});
  }

  Future<void> _setVibration(bool on) async {
    await widget.rank.setVibration(on);
    Haptics.enabled = on;
    Haptics.medium();
    if (mounted) setState(() {});
  }

  Future<void> _toggleReminder(bool on) async {
    final reminders = widget.reminders;
    if (reminders == null) return;
    if (on) {
      final allowed = await reminders.askPermission();
      if (!mounted) return;
      if (!allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Notifications are off for this app. Turn them on in your phone settings.'),
          ),
        );
        return;
      }
    }
    await widget.rank.setReminderOn(on);
    await reminders.refresh(widget.rank);
    if (mounted) setState(() {});
  }

  TimeOfDay get _reminderTime => TimeOfDay(
        hour: widget.rank.reminderMinutes ~/ 60,
        minute: widget.rank.reminderMinutes % 60,
      );

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null || !mounted) return;
    await widget.rank.setReminderMinutes(picked.hour * 60 + picked.minute);
    await widget.reminders?.refresh(widget.rank);
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
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your rank, streak and scores are stored only on this phone, '
                'and the game works offline. Ads are shown by Google AdMob, '
                "which may use your device's advertising ID to choose ads.",
              ),
              SizedBox(height: 12),
              Text('Full privacy policy:',
                  style: TextStyle(color: AppColors.muted, fontSize: 13)),
              SelectableText(
                _policyUrl,
                style: TextStyle(color: AppColors.lime, fontSize: 13),
              ),
            ],
          ),
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

  Future<void> _rate() async {
    try {
      await InAppReview.instance.openStoreListing();
    } catch (_) {
      // No store on this device: nothing to open.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ads = widget.ads;
    return NeonScaffold(
      bottomNavigationBar: ads == null ? null : AdBanner(ads: ads),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!widget.embedded)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              )
            else
              const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Seven quick taps reveal the developer-only ad insights line.
              onTap: () {
                _titleTaps++;
                if (_titleTaps >= 7 && !_insights) {
                  setState(() => _insights = true);
                }
              },
              child: const Text('Settings',
                  style:
                      TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 18),
            GlassPanel(
              child: Column(
                children: [
                  SwitchListTile(
                    value: widget.rank.soundOn,
                    onChanged: _setSound,
                    title: const Text('Sound effects'),
                    subtitle: const Text('Short sounds for answers and results',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
                  const Divider(height: 1, color: AppColors.line),
                  SwitchListTile(
                    value: widget.rank.colorBlindHelp,
                    onChanged: _setColorBlindHelp,
                    title: const Text('Colour-blind help'),
                    subtitle: const Text(
                        'Adds a shape to each colour in Color Clash',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
                  const Divider(height: 1, color: AppColors.line),
                  SwitchListTile(
                    value: widget.rank.reduceEffects,
                    onChanged: _setReduceFx,
                    title: const Text('Reduce effects'),
                    subtitle: const Text(
                        'Calmer visuals, easier on the battery. Fully applies next time you open the app.',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
                  const Divider(height: 1, color: AppColors.line),
                  SwitchListTile(
                    value: widget.rank.vibrationOn,
                    onChanged: _setVibration,
                    title: const Text('Vibration'),
                    subtitle: const Text('Feedback on taps and results',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
                ],
              ),
            ),
            if (widget.reminders != null) ...[
              const SizedBox(height: 14),
              GlassPanel(
              child: Column(
                  children: [
                    SwitchListTile(
                      value: widget.rank.reminderOn,
                      onChanged: _toggleReminder,
                      title: const Text('Daily reminder'),
                      subtitle: const Text(
                          'Zed nudges you, only on days you have not played yet',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 13)),
                    ),
                    if (widget.rank.reminderOn) ...[
                      const Divider(height: 1, color: AppColors.line),
                      ListTile(
                        title: const Text('Reminder time'),
                        subtitle: Text(ReminderService.timeLabel(_reminderTime),
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 13)),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: AppColors.muted),
                        onTap: _pickTime,
                      ),
                      const Divider(height: 1, color: AppColors.line),
                      ListTile(
                        title: const Text('Send a test reminder'),
                        onTap: () => widget.reminders?.sendTest(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            GlassPanel(
              child: Column(
                children: [
                  if (_adChoices) ...[
                    ListTile(
                      title: const Text('Ad privacy choices'),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.muted),
                      onTap: () => widget.ads?.showPrivacyOptions(),
                    ),
                    const Divider(height: 1, color: AppColors.line),
                  ],
                  if (ads != null && _insights) ...[
                    ListTile(
                      title: const Text('Ad insights'),
                      subtitle: Text(
                        'Stays on this phone: ${ads.brain.summary()}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.line),
                  ],
                  ListTile(
                    title: const Text('How it works'),
                    subtitle: const Text('Ranks, chest, boss, streaks and more',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 13)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.muted),
                    onTap: _howItWorks,
                  ),
                  const Divider(height: 1, color: AppColors.line),
                  ListTile(
                    title: const Text('Report a problem'),
                    subtitle: const Text(
                        'Copies details you can send to the developer',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 13)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.muted),
                    onTap: _reportProblem,
                  ),
                  const Divider(height: 1, color: AppColors.line),
                  ListTile(
                    title: const Text('Rate Beat the Bot'),
                    subtitle: const Text('Opens the Play Store',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 13)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.muted),
                    onTap: _rate,
                  ),
                  const Divider(height: 1, color: AppColors.line),
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
