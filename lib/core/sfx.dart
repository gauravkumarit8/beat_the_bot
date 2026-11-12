import 'package:audioplayers/audioplayers.dart';

/// The short sound effects in assets/sounds.
enum Sound { correct, wrong, win, lose, celebrate }

/// All sound goes through here so the Settings switch can turn it off.
/// Playing never throws: a missing or failing audio engine just means silence.
class Sfx {
  /// Off until the app turns it on at start-up (so tests stay silent).
  static bool enabled = false;

  static final List<AudioPlayer> _pool = [];
  static int _next = 0;
  static bool _ready = false;

  static Future<void> _setUp() async {
    if (_ready) return;
    // Do not take audio focus, so the player's music keeps playing.
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
      ),
    );
    for (var i = 0; i < 3; i++) {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      _pool.add(p);
    }
    _ready = true;
  }

  static Future<void> play(Sound sound) async {
    if (!enabled) return;
    try {
      await _setUp();
      final p = _pool[_next];
      _next = (_next + 1) % _pool.length;
      await p.stop();
      await p.play(AssetSource('sounds/${sound.name}.wav'), volume: 0.8);
    } catch (_) {
      // Silence is fine.
    }
  }
}
