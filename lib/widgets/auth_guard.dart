import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/providers/auth/auth_provider.dart';
import 'package:zippy/screens/auth/login_screen.dart';
import 'package:zippy/state/auth/auth_state.dart';

class AuthGuard extends ConsumerWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    switch (authState.status) {
      case AuthStatus.loading:
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        return child;
      case AuthStatus.unauthenticated:
        return LoginScreen();
    }
  }
}
