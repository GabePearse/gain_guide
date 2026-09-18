import 'exercise.dart';

class Workout {
  final int? id;
  final int? userId;
  final String name;
  final List<Exercise> exercises;
  final DateTime? completedAt;
  final String? scheduledWeekdays;
  final int? scheduledHour;
  final int? scheduledMinute;

  const Workout({
    this.id,
    this.userId,
    required this.name,
    this.exercises = const [],
    this.completedAt,
    this.scheduledWeekdays,
    this.scheduledHour,
    this.scheduledMinute,
  });

  Workout copyWith({
    int? id,
    int? userId,
    String? name,
    List<Exercise>? exercises,
    DateTime? completedAt,
    String? scheduledWeekdays,
    int? scheduledHour,
    int? scheduledMinute,
  }) {
    return Workout(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      completedAt: completedAt ?? this.completedAt,
      scheduledWeekdays: scheduledWeekdays ?? this.scheduledWeekdays,
      scheduledHour: scheduledHour ?? this.scheduledHour,
      scheduledMinute: scheduledMinute ?? this.scheduledMinute,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'completedAt': completedAt?.toIso8601String(),
      'scheduledWeekdays': scheduledWeekdays,
      'scheduledHour': scheduledHour,
      'scheduledMinute': scheduledMinute,
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'] as int?,
      userId: map['userId'] as int?,
      name: map['name'] as String,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      scheduledWeekdays: map['scheduledWeekdays'] as String?,
      scheduledHour: map['scheduledHour'] as int?,
      scheduledMinute: map['scheduledMinute'] as int?,
    );
  }
}
