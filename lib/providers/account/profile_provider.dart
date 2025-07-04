import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/models/entity/account/profile.dart';
import 'package:zippy/services/account/profile_service.dart';

final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() async {
    return await ProfileService.getProfile();
  }

  Future<void> refreshProfile() async {
    state = const AsyncLoading();
    try {
      final profile = await ProfileService.getProfile();
      state = AsyncData(profile);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updateProfile(Profile updated) async {
    await ProfileService.updateProfile(updated);
    await refreshProfile(); // Refresh after update
  }
}
