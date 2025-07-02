import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/models/entity/account/profile.dart';
import 'package:zippy/services/account/profile_service.dart';

final profileProvider = FutureProvider<Profile>((ref) async {
  return await ProfileService.getProfile();
});
