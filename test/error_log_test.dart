import 'package:beat_the_bot/core/error_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ErrorLog.attach(await SharedPreferences.getInstance());
  });

  test('keeps only the last five errors', () {
    for (var i = 1; i <= 7; i++) {
      ErrorLog.record('problem $i', null, now: DateTime(2026, 10, i));
    }
    final e = ErrorLog.entries();
    expect(e.length, 5);
    expect(e.first, contains('problem 3'));
    expect(e.last, contains('problem 7'));
  });

  test('long errors are cut short', () {
    ErrorLog.record('x' * 5000, StackTrace.current);
    expect(ErrorLog.entries().single.length, lessThanOrEqualTo(600));
  });

  test('the report lists what was recorded, or says there is nothing', () {
    expect(ErrorLog.report(), contains('No errors recorded.'));
    ErrorLog.record('boom', null);
    expect(ErrorLog.report(), contains('boom'));
    ErrorLog.clear();
    expect(ErrorLog.entries(), isEmpty);
  });
}
