import 'package:shared_preferences/shared_preferences.dart';

enum AdFormat { banner, interstitial, rewarded }

/// Learns, on this phone only, when the player usually plays and how they
/// react to ads, then tunes how often full-screen ads appear. Nothing here
/// leaves the device, and it needs no extra libraries.
///
/// What it can and cannot do: it decides WHEN a full-screen ad is allowed.
/// Which advertiser's ad appears, and how much it pays, is decided by
/// AdMob's own auction, not by the app.
class AdBrain {
  AdBrain(this._prefs);

  final SharedPreferences _prefs;

  static const int _minOpensForHabit = 8;
  static const int _minPaidForRichHours = 15;
  static const Duration _sessionGap = Duration(minutes: 30);
  static const Duration _quickExitWindow = Duration(seconds: 20);
  static const Duration _churnLookback = Duration(days: 3);

  DateTime? _lastActive;
  DateTime? _lastDismissed;
  int _sessionMatches = 0;

  // ---- storage helpers -----------------------------------------------------

  List<int> _hours(String key) {
    final out = List<int>.filled(24, 0);
    final raw = _prefs.getString(key);
    if (raw == null) return out;
    final parts = raw.split(',');
    for (var i = 0; i < 24 && i < parts.length; i++) {
      out[i] = int.tryParse(parts[i]) ?? 0;
    }
    return out;
  }

  void _saveHours(String key, List<int> v) => _prefs.setString(key, v.join(','));

  static Set<int> _topHours(List<int> v, int count) {
    final order = List<int>.generate(24, (i) => i)
      ..sort((a, b) => v[b].compareTo(v[a]));
    return {for (final h in order.take(count)) if (v[h] > 0) h};
  }

  // ---- what the player does --------------------------------------------------

  /// The app was opened or brought back. A gap of 30 minutes starts a new
  /// session and counts one open for that hour of the day.
  void onOpen(DateTime now) {
    final last = _lastActive;
    if (last == null || now.difference(last) > _sessionGap) {
      _sessionMatches = 0;
      final opens = _hours('abOpens');
      opens[now.hour]++;
      _saveHours('abOpens', opens);
    }
    _lastActive = now;
  }

  void onMatch(DateTime now) {
    _sessionMatches++;
    _lastActive = now;
  }

  void onInterstitialClosed(DateTime now) => _lastDismissed = now;

  /// The app went to the background. Leaving within 20 seconds of closing a
  /// full-screen ad is a sign the ad annoyed the player.
  void onAppPaused(DateTime now) {
    final closed = _lastDismissed;
    if (closed == null) return;
    _lastDismissed = null;
    if (now.difference(closed) > _quickExitWindow) return;
    final stamps = _quickExits(now)..add(now.millisecondsSinceEpoch);
    _prefs.setString('abQuick', stamps.join(','));
  }

  List<int> _quickExits(DateTime now) {
    final cutoff = now.subtract(_churnLookback).millisecondsSinceEpoch;
    final raw = _prefs.getString('abQuick') ?? '';
    return [
      for (final s in raw.split(','))
        if (int.tryParse(s) != null && int.parse(s) >= cutoff) int.parse(s),
    ];
  }

  // ---- what the ads earn (AdMob's estimate for each shown ad) ----------------

  void onPaid(AdFormat format, int micros, DateTime now) {
    if (micros <= 0) return;
    final key = format.name;
    _prefs.setInt('abMicros_$key', (_prefs.getInt('abMicros_$key') ?? 0) + micros);
    _prefs.setInt('abCount_$key', (_prefs.getInt('abCount_$key') ?? 0) + 1);
    _prefs.setInt('abMicrosTotal', (_prefs.getInt('abMicrosTotal') ?? 0) + micros);
    _prefs.setInt('abPaidCount', (_prefs.getInt('abPaidCount') ?? 0) + 1);
    final rev = _hours('abRev');
    rev[now.hour] += micros;
    _saveHours('abRev', rev);
  }

  /// Average estimated value of one shown ad of this format, in micros.
  int averageMicros(AdFormat format) {
    final n = _prefs.getInt('abCount_${format.name}') ?? 0;
    if (n == 0) return 0;
    return (_prefs.getInt('abMicros_${format.name}') ?? 0) ~/ n;
  }

  // ---- decisions -------------------------------------------------------------

  /// Hours of the day the player usually opens the game (empty until the app
  /// has seen enough opens to know).
  Set<int> habitHours() {
    final opens = _hours('abOpens');
    if (opens.fold<int>(0, (a, b) => a + b) < _minOpensForHabit) return {};
    return _topHours(opens, 3);
  }

  /// Hours when ads have earned the most on this phone.
  Set<int> richHours() {
    if ((_prefs.getInt('abPaidCount') ?? 0) < _minPaidForRichHours) return {};
    return _topHours(_hours('abRev'), 3);
  }

  bool isPeak(DateTime now) =>
      habitHours().contains(now.hour) || richHours().contains(now.hour);

  bool _churnRisk(DateTime now) => _quickExits(now).length >= 2;

  bool get _engaged => _sessionMatches >= 4;

  /// Matches the player must finish between two full-screen ads.
  int matchesBetweenAds(DateTime now) {
    if (_churnRisk(now)) return 4;
    if (isPeak(now) && _engaged) return 2;
    return 3;
  }

  /// Shortest time allowed between two full-screen ads.
  Duration minGap(DateTime now) {
    if (_churnRisk(now)) return const Duration(seconds: 180);
    if (isPeak(now) && _engaged) return const Duration(seconds: 90);
    return const Duration(seconds: 120);
  }

  /// One line for Settings, so the developer can see it learning.
  String summary() {
    final peaks = habitHours().toList()..sort();
    final when = peaks.isEmpty
        ? 'still learning your play times'
        : 'you play around ${peaks.map((h) => '$h:00').join(', ')}';
    final total = (_prefs.getInt('abMicrosTotal') ?? 0) / 1000000;
    return '$when. Est. ad earnings here: ${total.toStringAsFixed(4)}';
  }
}
