import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zippy/state/auth/auth_state.dart';

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

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

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
          default:
            // Handle unknown routes
            return MaterialPageRoute(
              builder: (context) => const AppInitializer(),
              settings: settings,
            );
        }
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

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
