import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/providers/theme_provider.dart';

class CustomInput extends StatelessWidget {
  final String labelKey;
  final String hintKey;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Function(String)? onChanged;
  final bool enabled;

  const CustomInput({
    super.key,
    required this.labelKey,
    required this.hintKey,
    this.obscureText = false,
    this.suffixIcon,
    this.controller,
    this.validator,
    this.keyboardType,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(labelKey),
          style: isDarkMode ? AppTypography.dmBodyText : AppTypography.bodyText,
        ),
        const SizedBox(height: 8),
        // Hide hint once the user has typed something
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller ?? ValueNotifier(TextEditingValue()),
          builder: (context, value, child) {
            final showHint = value.text.isEmpty;
            return TextFormField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              enabled: enabled,
              validator: validator,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: showHint ? tr(hintKey) : null,
                fillColor: isDarkMode
                    ? AppColors.dmInputColor
                    : AppColors.inputColor,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? AppColors.dmInputColor
                        : AppColors.inputColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.buttonColor,
                    width: 2,
                  ),
                ),
                suffixIcon: suffixIcon,
              ),
            );
          },
        ),
      ],
    );
  }
}
