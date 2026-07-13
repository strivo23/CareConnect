class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
  });

  final int id;
  final String email;
  final String fullName;
  final String phoneNumber;
  final String role;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      role: json['role']?.toString() ?? 'RESIDENT',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'role': role,
      };
}

class AuthSession {
  AuthSession({required this.accessToken, required this.refreshToken, required this.user});

  final String accessToken;
  final String refreshToken;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access']?.toString() ?? '',
      refreshToken: json['refresh']?.toString() ?? '',
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
    );
  }
}
