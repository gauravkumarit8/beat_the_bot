import 'package:flutter/services.dart';

/// All vibration goes through here so the Settings switch can turn it off.
class Haptics {
  static bool enabled = true;

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
