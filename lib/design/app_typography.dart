import 'package:flutter/material.dart';

import 'package:zippy/design/app_colors.dart';

class AppTypography {
  static TextStyle heading = TextStyle(
    fontFamily: 'Sen',
    fontWeight: FontWeight.w800,
    fontSize: 24,
    color: AppColors.headingColor,
  );

  static TextStyle helloText = TextStyle(
    fontFamily: 'Sen',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: AppColors.defaultColor,
  );

  static TextStyle titleText = TextStyle(
    fontFamily: 'Sen',
    fontWeight: FontWeight.w700,
    fontSize: 18,
    color: AppColors.headingColor,
  );

  static TextStyle bodyText = TextStyle(
    fontFamily: 'Sen',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.defaultColor,
  );
}
