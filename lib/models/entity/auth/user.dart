class User {
  final String? id;
  final String username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final bool? isVerified;

  User({
    this.id,
    required this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.isVerified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['phone'],
      isVerified: json['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'isVerified': isVerified,
    };
  }

  factory User.fromJwt(Map<String, dynamic> payload) {
    return User(
      username: payload['sub'] ?? '', // From .setSubject()
      email: payload['email'] ?? '', // From extraClaims
      isVerified: payload['status'] == 'ACTIVE', // From extraClaims
    );
  }

  // Getter for full name
  String get fullName {
    if (firstName != null && lastName != null) {
      return '${firstName!} ${lastName!}'.trim();
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    } else {
      return username;
    }
  }
}
