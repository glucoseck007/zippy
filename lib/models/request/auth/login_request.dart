class LoginRequest {
  final String credential;
  final String password;

  LoginRequest({required this.credential, required this.password});

  Map<String, dynamic> toJson() {
    return {'credential': credential, 'password': password};
  }
}
