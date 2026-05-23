class FriendReminder {
  final int? id;
  final int fromUserId;
  final int toUserId;
  final String fromName;
  final String toName;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;

  const FriendReminder({
    this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.fromName,
    required this.toName,
    required this.message,
    required this.createdAt,
    this.readAt,
  });

  factory FriendReminder.fromMap(Map<String, dynamic> map) {
    return FriendReminder(
      id: map['id'] as int?,
      fromUserId: map['fromUserId'] as int,
      toUserId: map['toUserId'] as int,
      fromName: map['fromName'] as String,
      toName: map['toName'] as String,
      message: map['message'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      readAt:
          map['readAt'] != null ? DateTime.parse(map['readAt'] as String) : null,
    );
  }
}
