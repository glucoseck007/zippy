import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  // Create theme with context-aware typography
  static ThemeData lightTheme(BuildContext context) => ThemeData(
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
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.buttonColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: AppTypography.buttonText(context),
      ),
    ),
  );

  static ThemeData darkTheme(BuildContext context) => ThemeData(
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
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.dmButtonColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: AppTypography.buttonText(context),
      ),
    ),
  );

  // Fallback static themes for cases where context is not available
  static final ThemeData lightThemeFallback = ThemeData(
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
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.buttonColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
  );

  static final ThemeData darkThemeFallback = ThemeData(
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
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.dmButtonColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
  );
}
