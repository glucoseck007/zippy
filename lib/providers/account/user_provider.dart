import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:zippy/models/entity/auth/user.dart';
import 'package:zippy/services/auth/token_service.dart';

final userProvider = FutureProvider<User?>((ref) async {
  final token = await TokenService.getAccessToken();

  if (token == null || JwtDecoder.isExpired(token)) {
    return null;
  }

  final payload = JwtDecoder.decode(token);
  return User.fromJwt(payload);
});
