import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:zippy/providers/auth_provider.dart';
import 'package:zippy/providers/language_provider.dart';
import 'package:zippy/providers/theme_provider.dart';
import 'package:zippy/screens/auth/login_screen.dart';
import 'package:zippy/screens/home.dart';
import 'package:zippy/screens/account/profile_screen.dart';
import 'package:zippy/utils/navigation_manager.dart';
import 'package:zippy/utils/snackbar_manager.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../models/entity/auth/user.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  // Helper method to change the app language
  void _changeLanguage(BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    // Use the provider to change the language
    await languageProvider.changeLanguage(context);

    // For more stubborn cases, we could try to rebuild the entire app
    // This is an advanced technique - we access the navigator and do a quick reset
    final navigatorState = Navigator.of(context, rootNavigator: true);
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/home';

    if (currentRoute == '/home') {
      // Force a more complete rebuild of the app by popping and pushing
      // This ensures the language change is propagated throughout the app
      navigatorState.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
          settings: const RouteSettings(name: '/home'),
        ),
        (route) => false, // Remove all previous routes
      );
    }

    // Show language change notification
    Future.delayed(const Duration(milliseconds: 500), () {
      final languageName = languageProvider.getCurrentLanguageName();
      SnackbarManager().showInfoSnackBar(
        tr('drawer.language_changed', args: [languageName]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    // Use watch instead of read to ensure rebuilds when theme changes
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final user = authProvider.currentUser;

    // Initialize language provider with current context locale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      languageProvider.initLocale(context);
    });

    return Drawer(
      backgroundColor: isDarkMode
          ? AppColors.dmCardColor
          : Colors.grey.shade200,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Section
              _buildUserInfo(context, user, isDarkMode),

              const SizedBox(height: 24),

              // Drawer Menu Items
              Expanded(
                child: _buildMenuItems(context, isDarkMode, themeProvider),
              ),

              // Logout Button
              _buildLogoutButton(context, authProvider, isDarkMode),

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
            backgroundColor: Colors.grey.shade300,
            child: Icon(
              Icons.person,
              size: 36,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.username ?? 'Guest',
                  style: isDarkMode
                      ? AppTypography.dmTitleText
                      : AppTypography.titleText,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Close the drawer
              Navigator.of(context).pop();
            },
            icon: Icon(
              Icons.close,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(
    BuildContext context,
    bool isDarkMode,
    ThemeProvider themeProvider,
  ) {
    return ListView(
      padding: EdgeInsets.zero,
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
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          title: Text(
            tr('drawer.account'),
            style: isDarkMode
                ? AppTypography.dmBodyText
                : AppTypography.bodyText,
          ),
        ),
        Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            return ListTile(
              onTap: () {
                // Handle language settings
                Navigator.of(context).pop(); // Close drawer

                // Call the helper method to change language
                _changeLanguage(context);
              },
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.globe,
                color: isDarkMode ? Colors.white70 : Colors.black54,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      languageProvider.getLanguageCode(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final isDark = themeProvider.isDarkMode;
            return ListTile(
              onTap: () {
                // Handle theme toggling
                themeProvider.toggleTheme(!isDark);
                // Show theme change notification
                SnackbarManager().showInfoSnackBar(
                  !isDark
                      ? tr('drawer.dark_mode_enabled')
                      : tr('drawer.light_mode_enabled'),
                );
                // We don't close the drawer so users can see the immediate visual change
              },
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isDark ? LucideIcons.sun : LucideIcons.moon,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              title: Text(
                isDark ? tr('drawer.light_mode') : tr('drawer.dark_mode'),
                style: isDark
                    ? AppTypography.dmBodyText
                    : AppTypography.bodyText,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogoutButton(
    BuildContext context,
    AuthProvider authProvider,
    bool isDarkMode,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // Handle logout
          NavigationManager.navigateToWithSlideTransition(
            context,
            const LoginScreen(),
          );
          authProvider.logout();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xffFA4032),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(tr('drawer.logout'), style: AppTypography.buttonText),
      ),
    );
  }
}
