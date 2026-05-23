class FriendSummary {
  final int friendUserId;
  final String displayName;
  final String email;
  final DateTime? lastCheckInAt;
  final int completedWorkouts;
  final String? lastWorkoutName;
  final DateTime? lastWorkoutAt;
  final int unreadReminders;

  const FriendSummary({
    required this.friendUserId,
    required this.displayName,
    required this.email,
    required this.lastCheckInAt,
    required this.completedWorkouts,
    this.lastWorkoutName,
    this.lastWorkoutAt,
    required this.unreadReminders,
  });
}
