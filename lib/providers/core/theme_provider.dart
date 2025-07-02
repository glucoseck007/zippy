import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/state/core/theme_state.dart';

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(ThemeState.light());

  void toggleTheme(bool isDark) {
    state = isDark ? ThemeState.dark() : ThemeState.light();
  }

  void toggle() {
    final newState = !state.isDarkMode;
    state = newState ? ThemeState.dark() : ThemeState.light();
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) => ThemeNotifier(),
);
