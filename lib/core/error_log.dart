import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the last few unexpected errors on this phone only, so a tester can
/// copy them from Settings and send them to the developer. Nothing is sent
/// anywhere automatically, and it adds no extra library.
class ErrorLog {
  static SharedPreferences? _prefs;
  static const int _keep = 5;
  static const int _maxLength = 600;
  static const String _key = 'errLog';

  /// Call once at start-up. Until then, [record] does nothing.
  static void attach(SharedPreferences prefs) => _prefs = prefs;

  static List<String> entries() => _prefs?.getStringList(_key) ?? const [];

  static void record(Object error, StackTrace? stack, {DateTime? now}) {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      var text = '${(now ?? DateTime.now()).toIso8601String()}  $error';
      final where = stack?.toString().split('\n').take(4).join(' | ');
      if (where != null && where.isNotEmpty) text += '  @ $where';
      if (text.length > _maxLength) text = text.substring(0, _maxLength);
      final all = [...entries(), text];
      final kept = all.length > _keep ? all.sublist(all.length - _keep) : all;
      prefs.setStringList(_key, kept);
    } catch (_) {
      // Logging must never cause a second problem.
    }
  }

  static void clear() => _prefs?.remove(_key);

  /// Text a player can paste into a message to the developer.
  static String report() {
    final list = entries();
    final b = StringBuffer('Beat the Bot problem report\n');
    b.writeln('Platform: ${defaultTargetPlatform.name}');
    if (list.isEmpty) {
      b.writeln('No errors recorded.');
    } else {
      for (final e in list) {
        b.writeln('- $e');
      }
    }
    return b.toString();
  }
}
