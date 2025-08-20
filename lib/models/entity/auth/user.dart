class User {
  final String? id;
  final String username;
  final String? email;
  final bool? isVerified;
  final String? role;

  User({
    this.id,
    required this.username,
    this.email,
    this.isVerified,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      isVerified: json['isVerified'] ?? false,
      role: json['role'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'isVerified': isVerified,
      'role': role,
    };
  }

  factory User.fromJwt(Map<String, dynamic> payload) {
    return User(
      username: payload['sub'] ?? '', // From .setSubject()
      email: payload['email'] ?? '', // From extraClaims
      isVerified: payload['status'] == 'ACTIVE', // From extraClaims
      role: payload['role'] ?? '', // From extraClaims
    );
  }
}
