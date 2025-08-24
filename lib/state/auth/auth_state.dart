import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zippy/models/entity/auth/user.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.unknown() = AuthStateUnknown;
  const factory AuthState.loading() = AuthStateLoading;
  const factory AuthState.authenticated({User? user}) = AuthStateAuthenticated;
  const factory AuthState.unauthenticated([String? errorMessage]) =
      AuthStateUnauthenticated;
}

enum AuthStatus { unknown, loading, authenticated, unauthenticated }

extension AuthStateX on AuthState {
  AuthStatus get status => when(
    unknown: () => AuthStatus.unknown,
    loading: () => AuthStatus.loading,
    authenticated: (_) => AuthStatus.authenticated,
    unauthenticated: (_) => AuthStatus.unauthenticated,
  );

  User? get user =>
      maybeWhen(authenticated: (user) => user, orElse: () => null);

  String? get errorMessage =>
      maybeWhen(unauthenticated: (error) => error, orElse: () => null);

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
}
