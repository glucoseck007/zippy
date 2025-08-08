import 'package:flutter/material.dart';

import 'package:zippy/design/app_colors.dart';

class AppTypography {
  // Helper function to calculate responsive font size based on screen width
  static double _getResponsiveFontSize(
    BuildContext context,
    double baseFontSize,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Base width for calculations (e.g., iPhone 14 width)
    const baseWidth = 390.0;

    // Calculate scale factor with min and max limits
    final scaleFactor = (screenWidth / baseWidth).clamp(0.8, 1.3);

    return baseFontSize * scaleFactor;
  }

  // Light mode text styles
  static TextStyle heading(BuildContext context) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w800,
    fontSize: _getResponsiveFontSize(context, 24),
    color: AppColors.headingColor,
  );

  static TextStyle helloText(BuildContext context) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w400,
    fontSize: _getResponsiveFontSize(context, 16),
    color: AppColors.defaultColor,
  );

  static TextStyle titleText(BuildContext context) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w700,
    fontSize: _getResponsiveFontSize(context, 18),
    color: AppColors.headingColor,
  );

  static TextStyle subTitleText(BuildContext context) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w500,
    fontSize: _getResponsiveFontSize(context, 16),
    color: AppColors.headingColor,
  );

  static TextStyle bodyText(BuildContext context) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w400,
    fontSize: _getResponsiveFontSize(context, 14),
    color: AppColors.defaultColor,
  );

  // Dark mode text styles
  static TextStyle dmHeading(BuildContext context) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w800,
    fontSize: _getResponsiveFontSize(context, 24),
    color: AppColors.dmHeadingColor,
  );

  static TextStyle dmHelloText(BuildContext context) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w400,
    fontSize: _getResponsiveFontSize(context, 16),
    color: AppColors.dmDefaultColor,
  );

  static TextStyle dmTitleText(BuildContext context) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w700,
    fontSize: _getResponsiveFontSize(context, 18),
    color: AppColors.dmHeadingColor,
  );

  static TextStyle dmSubTitleText(BuildContext context) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w500,
    fontSize: _getResponsiveFontSize(context, 16),
    color: AppColors.dmHeadingColor,
  );

  static TextStyle dmBodyText(BuildContext context) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w400,
    fontSize: _getResponsiveFontSize(context, 14),
    color: AppColors.dmDefaultColor,
  );

  static TextStyle buttonText(BuildContext context) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w600,
    fontSize: _getResponsiveFontSize(context, 16),
    color: Colors.white,
  );

  // static TextStyle dmButtonText = TextStyle(
  //   fontFamily: 'Quicksand',
  //   fontWeight: FontWeight.w600,
  //   fontSize: 16,
  //   color: Color,
  // );
}
