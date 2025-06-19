import '../models/user.dart';
import '../providers/auth_provider.dart';

enum Role { admin, user }

class AuthorizationService {
  /// Check if user has required role
  static bool hasRole(User? user, Role requiredRole) {
    if (user == null) return false;

    // This would typically check a roles field in the user model
    // For now, we'll use a simple example based on email or username patterns

    switch (requiredRole) {
      case Role.admin:
        return user.email.contains('admin') || user.username.contains('admin');
      case Role.user:
        return true; // All verified users are regular users by default
    }
  }

  /// Check if user has any of the required roles
  static bool hasAnyRole(User? user, List<Role> requiredRoles) {
    if (user == null) return false;
    return requiredRoles.any((role) => hasRole(user, role));
  }

  /// Check if user has all of the required roles
  static bool hasAllRoles(User? user, List<Role> requiredRoles) {
    if (user == null) return false;
    return requiredRoles.every((role) => hasRole(user, role));
  }

  /// Check if user can access a specific feature
  static bool canAccessFeature(User? user, String featureName) {
    if (user == null) return false;

    // Feature-based access control
    switch (featureName) {
      case 'admin_panel':
        return hasRole(user, Role.admin);
      case 'user_profile':
        return true; // All authenticated users can access their profile
      default:
        return hasRole(
          user,
          Role.user,
        ); // Regular users can access most features
    }
  }

  /// Get user's primary role
  static Role? getPrimaryRole(User? user) {
    if (user == null) return null;

    if (hasRole(user, Role.admin)) return Role.admin;
    return Role.user; // Default to regular user
  }

  /// Check if user's account is in good standing
  static bool isAccountActive(User? user) {
    if (user == null) return false;

    // Check if account is verified and not suspended
    return user.isVerified; // You might add more checks here
  }

  /// Comprehensive authorization check
  static AuthorizationResult authorize({
    required User? user,
    Role? requiredRole,
    List<Role>? anyOfRoles,
    List<Role>? allOfRoles,
    String? featureName,
    bool requiresVerification = true,
  }) {
    // Check if user exists
    if (user == null) {
      return AuthorizationResult.denied('User not authenticated');
    }

    // Check if account is active
    if (!isAccountActive(user)) {
      return AuthorizationResult.denied('Account is not active or verified');
    }

    // Check verification requirement
    if (requiresVerification && !user.isVerified) {
      return AuthorizationResult.denied('Account verification required');
    }

    // Check specific role
    if (requiredRole != null && !hasRole(user, requiredRole)) {
      return AuthorizationResult.denied(
        'Insufficient permissions: ${requiredRole.name} role required',
      );
    }

    // Check any of roles
    if (anyOfRoles != null && !hasAnyRole(user, anyOfRoles)) {
      return AuthorizationResult.denied(
        'Insufficient permissions: One of ${anyOfRoles.map((r) => r.name).join(', ')} roles required',
      );
    }

    // Check all roles
    if (allOfRoles != null && !hasAllRoles(user, allOfRoles)) {
      return AuthorizationResult.denied(
        'Insufficient permissions: All of ${allOfRoles.map((r) => r.name).join(', ')} roles required',
      );
    }

    // Check feature access
    if (featureName != null && !canAccessFeature(user, featureName)) {
      return AuthorizationResult.denied(
        'Access denied to feature: $featureName',
      );
    }

    return AuthorizationResult.granted();
  }
}

/// Result of authorization check
class AuthorizationResult {
  final bool isGranted;
  final String? reason;

  AuthorizationResult._(this.isGranted, this.reason);

  factory AuthorizationResult.granted() {
    return AuthorizationResult._(true, null);
  }

  factory AuthorizationResult.denied(String reason) {
    return AuthorizationResult._(false, reason);
  }

  bool get isDenied => !isGranted;
}

/// Mixin to provide authorization methods to widgets
mixin AuthorizationMixin {
  bool hasRole(AuthProvider authProvider, Role role) {
    return AuthorizationService.hasRole(authProvider.currentUser, role);
  }

  bool canAccessFeature(AuthProvider authProvider, String featureName) {
    return AuthorizationService.canAccessFeature(
      authProvider.currentUser,
      featureName,
    );
  }

  AuthorizationResult authorize(
    AuthProvider authProvider, {
    Role? requiredRole,
    List<Role>? anyOfRoles,
    List<Role>? allOfRoles,
    String? featureName,
    bool requiresVerification = true,
  }) {
    return AuthorizationService.authorize(
      user: authProvider.currentUser,
      requiredRole: requiredRole,
      anyOfRoles: anyOfRoles,
      allOfRoles: allOfRoles,
      featureName: featureName,
      requiresVerification: requiresVerification,
    );
  }
}
