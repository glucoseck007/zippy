import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:zippy/models/entity/auth/user.dart';
import 'package:zippy/utils/secure_storage.dart';

final tokenProvider = FutureProvider<String?>((ref) async {
  return await SecureStorage.getAccessToken();
});

final userProvider = Provider<User?>((ref) {
  final token = ref
      .watch(tokenProvider)
      .maybeWhen(data: (v) => v, orElse: () => null);
  if (token == null || JwtDecoder.isExpired(token)) return null;

  final payload = JwtDecoder.decode(token);
  return User.fromJwt(payload);
});
