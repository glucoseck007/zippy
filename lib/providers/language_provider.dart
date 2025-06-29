import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguageProvider extends ChangeNotifier {
  // Get the current locale
  Locale get currentLocale => _currentLocale;
  Locale _currentLocale = const Locale('vi', 'VN');

  // Update when app initializes
  void initLocale(BuildContext context) {
    _currentLocale = context.locale;
  }

  // Change the language of the app
  Future<void> changeLanguage(BuildContext context) async {
    final currentLocale = context.locale;

    // Toggle between English and Vietnamese
    final newLocale = currentLocale.languageCode == 'vi'
        ? const Locale('en', 'US')
        : const Locale('vi', 'VN');

    // Update context locale - this should propagate through EasyLocalization
    await context.setLocale(newLocale);

    // Update our provider state
    _currentLocale = newLocale;

    // Force a rebuild of all widgets listening to this provider
    notifyListeners();

    // For extra assurance that the locale change is applied,
    // we can add a small delay and check that the locale was actually changed
    await Future.delayed(const Duration(milliseconds: 200));

    // If the locale didn't change properly, try again with setLocale
    if (context.locale.languageCode != newLocale.languageCode) {
      await context.setLocale(newLocale);
      // Notify again after the second attempt
      notifyListeners();
    }
  }

  // Helper method to get display name of the current language
  String getCurrentLanguageName() {
    return _currentLocale.languageCode == 'en' ? 'English' : 'Tiếng Việt';
  }

  // Helper method to get language code display (EN/VI)
  String getLanguageCode() {
    return _currentLocale.languageCode.toUpperCase();
  }
}
