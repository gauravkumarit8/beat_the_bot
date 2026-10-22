import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0E1325);
  static const card = Color(0xFF1A2140);
  static const line = Color(0xFF2E3868);
  static const text = Color(0xFFF2F5FF);
  static const muted = Color(0xFF9AA6CC);
  static const lime = Color(0xFFB8F34A);
  static const coral = Color(0xFFFF6B5B);
  static const coralSoft = Color(0xFFFF8F82);
  static const amber = Color(0xFFFFB547);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.lime,
      onPrimary: AppColors.bg,
      surface: AppColors.card,
      onSurface: AppColors.text,
      error: AppColors.coral,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.bg
            : AppColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.lime
            : AppColors.line,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lime,
        foregroundColor: AppColors.bg,
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.lime,
        side: const BorderSide(color: AppColors.lime, width: 2),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
