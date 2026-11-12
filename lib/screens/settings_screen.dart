import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

import '../core/ads_service.dart';
import '../core/haptics.dart';
import '../core/rank_service.dart';
import '../core/sfx.dart';
import '../core/reminder_service.dart';
import '../core/theme.dart';
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
      'https://gauravkumarit8.github.io/beat_the_bot/privacy/';

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
            const Text('Settings',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
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
