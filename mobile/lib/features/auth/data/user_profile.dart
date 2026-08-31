class UserProfile {
  final int id;
  final String phoneNumber;
  final String? fullName;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.phoneNumber,
    this.fullName,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      phoneNumber: json['phone_number'] as String,
      fullName: json['full_name'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  UserProfile copyWith({
    String? fullName,
  }) {
    return UserProfile(
      id: id,
      phoneNumber: phoneNumber,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt,
    );
  }
}
