import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/providers/auth/auth_provider.dart';
import 'package:zippy/providers/core/language_provider.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/screens/auth/login_screen.dart';
import 'package:zippy/screens/account/profile_screen.dart';
import 'package:zippy/utils/navigation_manager.dart';
import 'package:zippy/utils/snackbar_manager.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../models/entity/auth/user.dart';

class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;

    // Get current user
    final user = ref.watch(currentUserProvider);

    return Drawer(
      backgroundColor: isDarkMode
          ? AppColors.dmCardColor
          : AppColors.backgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildUserInfo(context, user, isDarkMode),

              const SizedBox(height: 24),

              // Drawer Menu Items (now includes logout button)
              Expanded(child: _buildMenuItems(context, isDarkMode, ref)),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context, User? user, bool isDarkMode) {
    return SafeArea(
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: isDarkMode
                ? AppColors.dmCardColor
                : AppColors.cardColor,
            child: Icon(
              Icons.person,
              size: 36,
              color: isDarkMode
                  ? AppColors.dmHeadingColor
                  : AppColors.headingColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.username ?? tr('drawer.guest_user'),
                  style: isDarkMode
                      ? AppTypography.dmTitleText
                      : AppTypography.titleText,
                ),
                if (user?.email != null && user!.email!.isNotEmpty)
                  Text(
                    user.email!,
                    style: isDarkMode
                        ? AppTypography.subTitleText
                        : AppTypography.dmSubTitleText,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to change the app language
  void _changeLanguage(BuildContext context, WidgetRef ref) async {
    try {
      // Close drawer first to avoid context issues
      Navigator.of(context).pop();

      // Show loading overlay
      _showLanguageChangeLoading(context);

      // Small delay to ensure drawer is closed and loading is visible
      await Future.delayed(const Duration(milliseconds: 150));

      final languageNotifier = ref.read(languageProvider.notifier);

      // Change the language
      await languageNotifier.toggleLanguage(context);

      // Additional delay for smooth transition
      await Future.delayed(const Duration(milliseconds: 200));

      // Hide loading overlay
      if (context.mounted) {
        Navigator.of(context).pop(); // Remove loading overlay
      }

      // Show language change notification after a brief delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (context.mounted) {
          final newLanguage = ref.read(languageProvider).displayName;
          SnackbarManager().showInfoSnackBar(
            tr('drawer.language_changed', args: [newLanguage]),
          );
        }
      });
    } catch (e) {
      debugPrint('Error changing language: $e');
      // Hide loading overlay if still showing
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      // Show error message if language change fails
      if (context.mounted) {
        SnackbarManager().showErrorSnackBar(
          'Failed to change language. Please try again.',
        );
      }
    }
  }

  // Show loading overlay during language change
  void _showLanguageChangeLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext dialogContext) {
        return Consumer(
          builder: (context, ref, child) {
            final themeState = ref.watch(themeProvider);
            final isDarkMode = themeState.isDarkMode;

            return PopScope(
              canPop: false,
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.dmCardColor
                        : AppColors.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDarkMode
                                ? AppColors.dmButtonColor
                                : AppColors.buttonColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        tr('drawer.changing_language'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? AppColors.dmHeadingColor
                              : AppColors.headingColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait...',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? AppColors.dmDefaultColor
                              : AppColors.defaultColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMenuItems(BuildContext context, bool isDarkMode, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.only(left: 8),
      children: [
        ListTile(
          onTap: () {
            // Close drawer
            Navigator.of(context).pop();

            // Navigate to Profile Screen
            NavigationManager.navigateToWithSlideTransition(
              context,
              ProfileScreen(),
            );
          },
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            LucideIcons.user,
            color: isDarkMode
                ? AppColors.dmDefaultColor
                : AppColors.defaultColor,
          ),
          title: Text(
            tr('drawer.account'),
            style: isDarkMode
                ? AppTypography.dmBodyText
                : AppTypography.bodyText,
          ),
        ),
        Consumer(
          builder: (context, ref, child) {
            return ListTile(
              onTap: () {
                // Call the helper method to change language (it will close drawer)
                _changeLanguage(context, ref);
              },
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.globe,
                color: isDarkMode
                    ? AppColors.dmDefaultColor
                    : AppColors.defaultColor,
              ),
              title: Row(
                children: [
                  Text(
                    tr('drawer.language'),
                    style: isDarkMode
                        ? AppTypography.dmBodyText
                        : AppTypography.bodyText,
                  ),
                  const SizedBox(width: 8),
                  Consumer(
                    builder: (context, ref, child) {
                      final languageState = ref.watch(languageProvider);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.dmInputColor
                              : AppColors.inputColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          languageState.code,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? AppColors.dmDefaultColor
                                : AppColors.defaultColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        Consumer(
          builder: (context, ref, child) {
            final themeState = ref.watch(themeProvider);
            return ListTile(
              onTap: () {
                // Handle theme toggling
                ref.read(themeProvider.notifier).toggle();
                // Show theme change notification
                SnackbarManager().showInfoSnackBar(
                  themeState.isDarkMode
                      ? tr('drawer.light_mode_enabled')
                      : tr('drawer.dark_mode_enabled'),
                );
                // We don't close the drawer so users can see the immediate visual change
              },
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                themeState.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
                color: themeState.isDarkMode
                    ? AppColors.dmDefaultColor
                    : AppColors.defaultColor,
              ),
              title: Text(
                themeState.isDarkMode
                    ? tr('drawer.light_mode')
                    : tr('drawer.dark_mode'),
                style: themeState.isDarkMode
                    ? AppTypography.dmBodyText
                    : AppTypography.bodyText,
              ),
            );
          },
        ),
        // Logout Button as ListTile
        ListTile(
          onTap: () {
            NavigationManager.navigateToWithSlideTransition(
              context,
              const LoginScreen(),
            );
            ref.read(authProvider.notifier).logout();
          },
          contentPadding: EdgeInsets.zero,
          leading: Icon(LucideIcons.logOut, color: AppColors.rejectColor),
          title: Text(
            tr('drawer.logout'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.rejectColor,
            ),
          ),
        ),
      ],
    );
  }
}
