import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:zippy/screens/auth/login_screen.dart';
import 'package:zippy/screens/home.dart';
import 'package:zippy/screens/profile_screen.dart';
import 'package:zippy/screens/admin_panel_screen.dart';
import 'package:zippy/widgets/auth_guard.dart';
import 'package:zippy/widgets/dev_auth_switcher.dart';

import 'design/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Set this to true for automatic mock authentication (DEV MODE ONLY)
  static const bool _useMockAuth = true; // Enabled for dev mode

  @override
  void initState() {
    super.initState();

    // Development-only: Set up mock authentication if needed
    // This should be disabled in production
    _setupDevelopmentAuth();
  }

  /// Sets up mock authentication for development convenience
  void _setupDevelopmentAuth() {
    if (_useMockAuth && kDebugMode) {
      // If we're using mock auth and in debug mode, set up auto-login

      // We need to delay this slightly to ensure providers are ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;

        // Get auth provider safely
        try {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );

          // Only set mock authentication if not already authenticated
          if (authProvider.authState != AuthState.authenticated) {
            authProvider.setMockAuthentication(
              role: 'USER', // Change to 'ADMIN' to test admin features
              username: 'dev_user',
              email: 'dev@example.com',
              firstName: 'Developer',
              lastName: 'Test',
            );

            // Log to console only - UI notification will be handled in MaterialApp builder
            debugPrint('⚠️ DEVELOPMENT MODE: Using mock authentication');
          }
        } catch (e) {
          // Log any errors during initialization
          debugPrint('Error setting mock authentication: $e');
        }
      });
    }
  }

  // We'll move notification display logic to the MaterialApp's builder
  // This is a safer approach than using a separate method

  @override
  Widget build(BuildContext context) {
    // Don't call notification display here - we'll handle it in the MaterialApp

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Zippy Delivery App',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            EasyLocalization.of(context)!.delegate,
          ],
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          navigatorObservers: [AuthRouteObserver()],
          // Use builder to inject dev auth switcher inside the MaterialApp
          builder: (context, child) {
            // Show dev mode notification after MaterialApp is fully built
            if (kDebugMode) {
              // Using a local variable to maintain class reference
              final bool showMockNotification = _useMockAuth;
              final State appState = this;

              // Delay notification to ensure everything is fully built
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Only show notification if still mounted and using mock auth
                if (showMockNotification && appState.mounted) {
                  try {
                    // Now it's safe to use ScaffoldMessenger
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '⚠️ DEVELOPMENT MODE: Using mock authentication',
                        ),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  } catch (e) {
                    debugPrint('Unable to show auth notification: $e');
                  }
                }
              });
            }

            // Wrap with Directionality for proper text direction
            // Wrap with Overlay for tooltip support
            // Then wrap with a Stack to properly position the DevAuthSwitcher
            return Directionality(
              textDirection: Directionality.of(context),
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          child ?? const SizedBox.shrink(),
                          // Development only auth switcher (only visible in debug mode)
                          if (kDebugMode) const DevAuthSwitcher(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
          home: const AppInitializer(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const AuthGuard(child: HomeScreen()),
            '/profile': (context) => const AuthGuard(child: ProfileScreen()),
            '/admin': (context) => const AuthGuard(child: AdminPanelScreen()),
          },
        );
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Initialize auth state - this will check for stored tokens
    await authProvider.initialize();

    // The mock authentication in _MyAppState._setupDevelopmentAuth will
    // be applied after this if enabled, so we don't need to do anything else here
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        switch (authProvider.authState) {
          case AuthState.unknown:
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading...'),
                  ],
                ),
              ),
            );

          case AuthState.authenticated:
            return const HomeScreen();

          case AuthState.unauthenticated:
            return const LoginScreen();
        }
      },
    );
  }
}
