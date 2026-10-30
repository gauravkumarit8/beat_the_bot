import 'package:beat_the_bot/core/reminder_service.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime(2026, 10, 22);

  test('the first reminder mentions a real streak', () {
    expect(reminderMessage(1, 5, base), contains('5-day streak'));
  });

  test('without a streak the first reminder is a normal taunt', () {
    final text = reminderMessage(1, 1, base);
    expect(text, isNotEmpty);
    expect(text, isNot(contains('streak is on the line')));
  });

  test('every one of the 14 days has a message', () {
    for (var day = 1; day <= ReminderService.daysAhead; day++) {
      expect(reminderMessage(day, 0, base), isNotEmpty);
    }
  });

  test('time labels read like a clock', () {
    expect(ReminderService.timeLabel(const TimeOfDay(hour: 19, minute: 0)),
        '7:00 PM');
    expect(ReminderService.timeLabel(const TimeOfDay(hour: 0, minute: 5)),
        '12:05 AM');
    expect(ReminderService.timeLabel(const TimeOfDay(hour: 12, minute: 30)),
        '12:30 PM');
    expect(ReminderService.timeLabel(const TimeOfDay(hour: 9, minute: 5)),
        '9:05 AM');
  });
}
