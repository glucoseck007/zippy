class User {
  final String? id;
  final String username;
  final String? email;
  final bool? isVerified;

  User({this.id, required this.username, this.email, this.isVerified});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      isVerified: json['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
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
}
