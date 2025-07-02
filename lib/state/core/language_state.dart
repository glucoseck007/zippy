import 'package:flutter/material.dart';

class LanguageState {
  final Locale locale;

  const LanguageState(this.locale);

  LanguageState copyWith(Locale newLocale) => LanguageState(newLocale);

  String get displayName =>
      locale.languageCode == 'en' ? 'English' : 'Tiếng Việt';
  String get code => locale.languageCode.toUpperCase();
}
