import 'package:flutter/material.dart';

import 'package:zippy/design/app_colors.dart';

class AppTypography {
  // Light mode text styles
  static TextStyle heading = TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w800,
    fontSize: 24,
    color: AppColors.headingColor,
  );

  static TextStyle helloText = TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: AppColors.defaultColor,
  );

  static TextStyle titleText = TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w700,
    fontSize: 18,
    color: AppColors.headingColor,
  );

  static TextStyle subTitleText = TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: AppColors.headingColor,
  );

  static TextStyle bodyText = TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.defaultColor,
  );

  // Dark mode text styles
  static TextStyle dmHeading = TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w800,
    fontSize: 24,
    color: AppColors.dmHeadingColor,
  );

  static TextStyle dmHelloText = TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: AppColors.dmDefaultColor,
  );

  static TextStyle dmTitleText = TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w700,
    fontSize: 18,
    color: AppColors.dmHeadingColor,
  );

  static TextStyle dmSubTitleText = TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: AppColors.dmHeadingColor,
  );

  static TextStyle dmBodyText = TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.dmDefaultColor,
  );

  static TextStyle buttonText = TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: Colors.white,
  );

  // static TextStyle dmButtonText = TextStyle(
  //   fontFamily: 'Quicksand',
  //   fontWeight: FontWeight.w600,
  //   fontSize: 16,
  //   color: Color,
  // );
}
