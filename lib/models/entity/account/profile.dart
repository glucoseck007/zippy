class Profile {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String address;

  Profile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.address,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
    );
  }
}
