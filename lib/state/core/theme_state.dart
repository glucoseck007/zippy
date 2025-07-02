import 'package:flutter/material.dart';

class ThemeState {
  final bool isDarkMode;
  final ThemeMode themeMode;

  const ThemeState({required this.isDarkMode, required this.themeMode});

  factory ThemeState.light() =>
      const ThemeState(isDarkMode: false, themeMode: ThemeMode.light);

  factory ThemeState.dark() =>
      const ThemeState(isDarkMode: true, themeMode: ThemeMode.dark);
}
