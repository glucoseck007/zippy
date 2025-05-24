import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.backgroundColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundColor,
      foregroundColor: AppColors.headingColor,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.defaultColor),
    ),
    colorScheme: ColorScheme.light(
      primary: AppColors.buttonColor,
      secondary: AppColors.selectedColor,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.dmBackgroundColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.dmBackgroundColor,
      foregroundColor: AppColors.dmHeadingColor,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.dmDefaultColor),
    ),
    colorScheme: ColorScheme.dark(
      primary: AppColors.dmButtonColor,
      secondary: AppColors.dmSelectedColor,
    ),
  );
}
