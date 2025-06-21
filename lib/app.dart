import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:zippy/screens/auth/login_screen.dart';
import 'package:zippy/screens/home.dart';
import 'design/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';

// Global key for accessing ScaffoldMessenger throughout the app
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

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

            // Show developer notification
            rootScaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: const Text('⚠️ DEBUG MODE: Auto-login enabled'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
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
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          title: 'Zippy Mobile App',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            ...context
                .localizationDelegates, // Safe way to access EasyLocalization delegates
          ],
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          // In debug mode with mock auth enabled, start directly at home screen
          initialRoute: (kDebugMode && _useMockAuth) ? '/home' : '/',
          routes: {
            '/': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
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
    // In debug mode with _useMockAuth enabled, skip auth checks entirely
    if (kDebugMode && _MyAppState._useMockAuth) {
      return const HomeScreen();
    }

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
