class RegisterRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String password;
  final String confirmPassword;
  final bool termsAccepted;
  final String phone;

  RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    required this.password,
    required this.phone,
    this.confirmPassword = '',
    this.termsAccepted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'confirmPassword': confirmPassword,
      'termsAccepted': termsAccepted,
      'password': password,
      'phone': phone,
    };
  }
}
