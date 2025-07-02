import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/design/app_typography.dart';
import '../design/app_colors.dart';
import '../providers/core/theme_provider.dart';

class ServiceItem extends ConsumerWidget {
  final String text;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;

  const ServiceItem({
    super.key,
    required this.text,
    required this.onTap,
    this.icon,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProviderState = ref.watch(themeProvider);
    final isDarkMode = themeProviderState.isDarkMode;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          height: 79.2,
          width: 112.3,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color:
                backgroundColor ??
                (isDarkMode ? AppColors.dmCardColor : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            children: [
              Icon(
                icon ??
                    LucideIcons
                        .package, // Use provided icon or fallback to package icon
                color:
                    iconColor ??
                    (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style:
                    (isDarkMode
                            ? AppTypography.dmSubTitleText
                            : AppTypography.titleText)
                        .copyWith(fontSize: 14, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
