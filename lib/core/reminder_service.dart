import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'rank_service.dart';

const List<String> _lines = [
  'Zed practised all night. Your move.',
  'A revenge bonus is waiting. So am I.',
  "Today's dare is live. Think you can handle it?",
  'Your rank is slipping. I am not sorry.',
  'The Daily Gauntlet is open. Bring your best.',
  'Still alive? Prove it. Two minutes.',
  'I have been beating myself to stay sharp. Come and help.',
  'Your brain age is waiting for an update.',
  'One match. Zed vs you. You know you want to.',
  'I told my circuits you would be back today.',
  'A weekly goal is still open. Go and finish it.',
  'Rumour says you can beat me. Prove the rumour.',
  'My sensors miss you. Slightly.',
  'Your streak will not build itself.',
];

/// The text of the reminder [dayOffset] days from [base].
/// The first reminder mentions the streak, because that is the one that hurts.
String reminderMessage(int dayOffset, int streak, DateTime base) {
  if (dayOffset == 1 && streak >= 2) {
    return 'Your $streak-day streak is on the line. Zed is counting.';
  }
  return _lines[(base.day + dayOffset) % _lines.length];
}

/// Daily reminders from Zed, scheduled on the phone with no server.
///
/// Every time the app opens, the next 14 reminders are rescheduled starting
/// from tomorrow. So a reminder only arrives on a day you have not opened the
/// app yet: opening the app before the reminder time cancels it.
class ReminderService {
  ReminderService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const int _firstId = 1000;
  static const int daysAhead = 14;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminder',
      'Daily reminder',
      channelDescription: 'A daily nudge from Zed',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_zed'),
        ),
      );
      _ready = true;
    } catch (_) {
      // Reminders are optional. The game works without them.
    }
  }

  /// Asks for notification permission (needed on Android 13 and newer).
  Future<bool> askPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Schedules or cancels reminders to match the player's setting.
  Future<void> refresh(RankService rank, {DateTime? now}) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (!rank.reminderOn) return;
      final base = now ?? DateTime.now();
      final minutes = rank.reminderMinutes;
      for (var i = 1; i <= daysAhead; i++) {
        final when = DateTime(
            base.year, base.month, base.day + i, minutes ~/ 60, minutes % 60);
        await _plugin.zonedSchedule(
          id: _firstId + i,
          title: 'ZED-9',
          body: reminderMessage(i, rank.streak, base),
          scheduledDate: tz.TZDateTime.from(when, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // Ignore: a failed schedule must never stop the app.
    }
  }

  /// Shows a reminder right now, so the player can see what it looks like.
  Future<void> sendTest() async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _firstId,
        title: 'ZED-9',
        body: 'This is what a reminder looks like. Now go and beat me.',
        notificationDetails: _details,
      );
    } catch (_) {}
  }

  static String timeLabel(TimeOfDay t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }
}
