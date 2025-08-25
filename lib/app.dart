import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zippy/state/auth/auth_state.dart';
import 'package:zippy/services/app_initialization_service.dart';
import 'package:zippy/services/api_client.dart';
import 'package:zippy/services/storage/persistent_mqtt_manager.dart';
import 'package:zippy/services/native/background_service_debugger.dart';

import 'screens/auth/login_screen.dart';
import 'screens/home.dart';
import 'design/app_theme.dart';
import 'providers/auth/auth_provider.dart';
import 'providers/core/theme_provider.dart';
import 'providers/core/language_provider.dart';

// Global key for showing snackbars from anywhere
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    // Add lifecycle observer for persistent MQTT management
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Set up auth failure callback for API client
      ApiClient.setAuthFailureCallback((reason) {
        if (mounted) {
          // Force logout through auth provider
          ref.read(authProvider.notifier).forceLogout(reason);
        }
      });

      // Initialize app services (MQTT, etc.)
      AppInitializationService.initialize(ref);

      // Initialize language state from EasyLocalization
      ref.read(languageProvider.notifier).initLocale(context);

      // Sync theme with system setting
      final brightness = MediaQuery.platformBrightnessOf(context);
      ref
          .read(themeProvider.notifier)
          .toggleTheme(brightness == Brightness.dark);
    });
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Notify persistent MQTT manager of lifecycle changes
    PersistentMqttManager.instance.onAppLifecycleChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final language = ref.watch(languageProvider);

    return MaterialApp(
      key: ValueKey(
        language.locale.toString(),
      ), // Force rebuild when language changes
      title: 'Zippy Mobile App',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      themeMode: theme.themeMode,
      theme: AppTheme.lightThemeFallback,
      darkTheme: AppTheme.darkThemeFallback,
      locale: language.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        ...context.localizationDelegates,
      ],
      // Add route generation
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
          case '/home':
            return MaterialPageRoute(
              builder: (context) => const AppInitializer(),
              settings: settings,
            );
          case '/login':
            return MaterialPageRoute(
              builder: (context) => const LoginScreen(),
              settings: settings,
            );
          case '/debug':
            // Check debug action from environment variables
            const debugAction = String.fromEnvironment('DEBUG_ACTION');
            if (debugAction == 'check_progress') {
              // Run the check and exit
              BackgroundServiceDebugger.checkForDuplicateTripData();
              BackgroundServiceDebugger.checkRawProgressData();
              return MaterialPageRoute(
                builder: (context) => const Scaffold(
                  body: Center(child: Text('Debug check complete')),
                ),
                settings: settings,
              );
            } else if (debugAction == 'clear_progress') {
              // Clear progress data and exit
              BackgroundServiceDebugger.clearAllProgressData();
              return MaterialPageRoute(
                builder: (context) => const Scaffold(
                  body: Center(child: Text('Progress data cleared')),
                ),
                settings: settings,
              );
            }
          default:
            // Handle unknown routes
            return MaterialPageRoute(
              builder: (context) => const AppInitializer(),
              settings: settings,
            );
        }
        return null;
      },
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends ConsumerStatefulWidget {
  const AppInitializer({super.key});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final authNotifier = ref.read(authProvider.notifier);

    if (!authNotifier.isInit) {
      await ref.read(authProvider.notifier).checkAuth();
    }
  }

  void _showAuthErrorMessage(String? message) {
    if (message != null && message.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
              },
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // Show error message when authentication fails
    if (auth.status == AuthStatus.unauthenticated &&
        auth.errorMessage != null) {
      _showAuthErrorMessage(auth.errorMessage);
    }

    switch (auth.status) {
      case AuthStatus.unknown:
      case AuthStatus.loading:
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

      case AuthStatus.authenticated:
        return const HomeScreen();

      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
