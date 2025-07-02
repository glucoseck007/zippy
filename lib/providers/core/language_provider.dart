import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:zippy/state/core/language_state.dart';

class LanguageNotifier extends StateNotifier<LanguageState> {
  LanguageNotifier() : super(const LanguageState(Locale('vi', 'VN')));

  void initLocale(BuildContext context) {
    state = LanguageState(context.locale);
  }

  Future<void> toggleLanguage(BuildContext context) async {
    try {
      final currentLocale = context.locale;
      final newLocale = currentLocale.languageCode == 'vi'
          ? const Locale('en', 'US')
          : const Locale('vi', 'VN');

      // Check if context is still mounted before using it
      if (context.mounted) {
        // Update our Riverpod state first to trigger immediate UI updates
        state = LanguageState(newLocale);

        // Small delay to ensure the state change is processed
        await Future.delayed(const Duration(milliseconds: 50));

        // Then update the EasyLocalization context
        await context.setLocale(newLocale);

        // Small delay to ensure the locale change propagates throughout the app
        await Future.delayed(const Duration(milliseconds: 150));

        // Update state again to ensure consistency
        state = LanguageState(newLocale);
      }
    } catch (e) {
      debugPrint('Error in toggleLanguage: $e');
      // If there's an error, revert the state change
      rethrow;
    }
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, LanguageState>(
  (ref) => LanguageNotifier(),
);
