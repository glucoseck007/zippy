import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';

/// Widget that protects routes requiring authentication
class AuthGuard extends StatelessWidget {
  final Widget child;
  final Widget? loadingWidget;
  final Widget? unauthenticatedWidget;

  const AuthGuard({
    super.key,
    required this.child,
    this.loadingWidget,
    this.unauthenticatedWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        switch (authProvider.authState) {
          case AuthState.unknown:
            // Show loading while checking authentication
            return loadingWidget ??
                const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );

          case AuthState.authenticated:
            // User is authenticated, show the protected content
            return child;

          case AuthState.unauthenticated:
            // User not authenticated, redirect to login
            return unauthenticatedWidget ?? const LoginScreen();
        }
      },
    );
  }
}

/// Function to check if route requires authentication
bool requiresAuth(String routeName) {
  const protectedRoutes = [
    '/home',
    '/profile',
    '/orders',
    '/settings',
    '/delivery',
    // Add more protected routes here
  ];

  return protectedRoutes.contains(routeName);
}

/// Custom route observer to handle authentication checks
class AuthRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _checkAuthenticationForRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _checkAuthenticationForRoute(newRoute);
    }
  }

  void _checkAuthenticationForRoute(Route<dynamic> route) {
    if (route.settings.name != null && requiresAuth(route.settings.name!)) {
      // Additional auth check logic can be added here if needed
      print('Accessing protected route: ${route.settings.name}');
    }
  }
}
