import 'dart:convert';

import 'package:zippy/models/entity/account/profile.dart';
import 'package:zippy/services/api_client.dart';
import 'package:zippy/utils/secure_storage.dart';

class ProfileService {
  static Future<Profile> getProfile() async {
    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      throw Exception("No access token found");
    }
    ;

    final response = await ApiClient.get('/account/profile', token: token);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = body['data'];
      return Profile.fromJson(data);
    } else {
      final error = jsonDecode(response.body)['message'];
      throw Exception("Failed to load profile: $error");
    }
  }
}
