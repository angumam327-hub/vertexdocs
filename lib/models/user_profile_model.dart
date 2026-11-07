class UserProfileModel {
  final String name;
  final String email;
  final String phone;
  final String bio;
  final String? photoPath;
  final DateTime? updatedAt;

  const UserProfileModel({
    this.name = 'VertexDocs User',
    this.email = '',
    this.phone = '',
    this.bio = 'Productivity enthusiast using VertexDocs.',
    this.photoPath,
    this.updatedAt,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'V';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  UserProfileModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? bio,
    String? photoPath,
    bool clearPhoto = false,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'bio': bio,
      'photoPath': photoPath,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      name: json['name'] as String? ?? 'VertexDocs User',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      bio:
          json['bio'] as String? ?? 'Productivity enthusiast using VertexDocs.',
      photoPath: json['photoPath'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}
