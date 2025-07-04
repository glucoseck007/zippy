import 'dart:convert';

import 'package:zippy/models/entity/account/profile.dart';
import 'package:zippy/services/api_client.dart';

class ProfileService {
  static Future<Profile> getProfile() async {
    final response = await ApiClient.get('/account/profile');

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = body['data'];
      return Profile.fromJson(data);
    } else {
      final error = jsonDecode(response.body)['message'];
      throw Exception("Failed to load profile: $error");
    }
  }

  static Future<void> updateProfile(Profile profile) async {
    final response = await ApiClient.put(
      '/account/edit-profile',
      body: profile.toJson(),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['message'];
      throw Exception("Failed to update profile: $error");
    }
  }
}
