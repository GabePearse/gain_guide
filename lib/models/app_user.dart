class AppUser {
  final int? id;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final DateTime? lastCheckInAt;

  const AppUser({
    this.id,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.lastCheckInAt,
  });

  AppUser copyWith({
    int? id,
    String? displayName,
    String? email,
    DateTime? createdAt,
    DateTime? lastCheckInAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      lastCheckInAt: lastCheckInAt ?? this.lastCheckInAt,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as int?,
      displayName: map['displayName'] as String,
      email: map['email'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastCheckInAt: map['lastCheckInAt'] != null
          ? DateTime.parse(map['lastCheckInAt'] as String)
          : null,
    );
  }
}
