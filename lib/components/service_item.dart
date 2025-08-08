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
          height: MediaQuery.of(context).size.height * 0.12,
          width: MediaQuery.of(context).size.width * 0.25,
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.02,
            vertical: MediaQuery.of(context).size.height * 0.01,
          ),
          decoration: BoxDecoration(
            color:
                backgroundColor ??
                (isDarkMode ? AppColors.dmCardColor : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Icon(
                  icon ??
                      LucideIcons
                          .package, // Use provided icon or fallback to package icon
                  color:
                      iconColor ??
                      (isDarkMode
                          ? Colors.grey.shade300
                          : Colors.grey.shade700),
                  size:
                      MediaQuery.of(context).size.width *
                      0.06, // Dynamic icon size
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.005,
              ), // Dynamic spacing
              Flexible(
                child: Text(
                  text,
                  style:
                      (isDarkMode
                              ? AppTypography.dmSubTitleText(context)
                              : AppTypography.titleText(context))
                          .copyWith(
                            fontSize:
                                MediaQuery.of(context).size.width *
                                0.03, // Dynamic font size
                            color: textColor,
                          ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
