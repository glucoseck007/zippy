import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/authorization_service.dart';

/// Widget that conditionally shows content based on user permissions
class PermissionGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  final Role? requiredRole;
  final List<Role>? anyOfRoles;
  final List<Role>? allOfRoles;
  final String? featureName;
  final bool requiresVerification;
  final VoidCallback? onAccessDenied;

  const PermissionGuard({
    super.key,
    required this.child,
    this.fallback,
    this.requiredRole,
    this.anyOfRoles,
    this.allOfRoles,
    this.featureName,
    this.requiresVerification = true,
    this.onAccessDenied,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final result = AuthorizationService.authorize(
          user: authProvider.currentUser,
          requiredRole: requiredRole,
          anyOfRoles: anyOfRoles,
          allOfRoles: allOfRoles,
          featureName: featureName,
          requiresVerification: requiresVerification,
        );

        if (result.isGranted) {
          return child;
        } else {
          if (onAccessDenied != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onAccessDenied!();
            });
          }
          return fallback ?? const SizedBox.shrink();
        }
      },
    );
  }
}

/// Widget that shows different content based on user role
class RoleBasedWidget extends StatelessWidget {
  final Widget? adminWidget;
  final Widget? userWidget;
  final Widget? defaultWidget;

  const RoleBasedWidget({
    super.key,
    this.adminWidget,
    this.userWidget,
    this.defaultWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;
        final primaryRole = AuthorizationService.getPrimaryRole(user);

        switch (primaryRole) {
          case Role.admin:
            return adminWidget ?? defaultWidget ?? const SizedBox.shrink();
          case Role.user:
            return userWidget ?? defaultWidget ?? const SizedBox.shrink();
          case null:
            return defaultWidget ?? const SizedBox.shrink();
        }
      },
    );
  }
}

/// Button that is only enabled if user has required permissions
class PermissionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Role? requiredRole;
  final List<Role>? anyOfRoles;
  final List<Role>? allOfRoles;
  final String? featureName;
  final bool requiresVerification;
  final VoidCallback? onAccessDenied;
  final ButtonStyle? style;

  const PermissionButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.requiredRole,
    this.anyOfRoles,
    this.allOfRoles,
    this.featureName,
    this.requiresVerification = true,
    this.onAccessDenied,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final result = AuthorizationService.authorize(
          user: authProvider.currentUser,
          requiredRole: requiredRole,
          anyOfRoles: anyOfRoles,
          allOfRoles: allOfRoles,
          featureName: featureName,
          requiresVerification: requiresVerification,
        );

        return ElevatedButton(
          onPressed: result.isGranted
              ? onPressed
              : () {
                  if (onAccessDenied != null) {
                    onAccessDenied!();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.reason ?? 'Access denied'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
          style: style,
          child: child,
        );
      },
    );
  }
}

/// Helper widget to show user's role information
class UserRoleInfo extends StatelessWidget {
  const UserRoleInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;
        final primaryRole = AuthorizationService.getPrimaryRole(user);

        if (user == null) {
          return const Chip(
            label: Text('Not logged in'),
            backgroundColor: Colors.grey,
          );
        }

        Color roleColor;
        switch (primaryRole) {
          case Role.admin:
            roleColor = Colors.red;
            break;
          case Role.user:
            roleColor = Colors.blue;
            break;
          case null:
            roleColor = Colors.grey;
            break;
        }

        return Chip(
          label: Text(
            primaryRole?.name.toUpperCase() ?? 'UNKNOWN',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: roleColor,
        );
      },
    );
  }
}
