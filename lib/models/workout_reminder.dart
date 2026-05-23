import 'workout.dart';

class WorkoutReminder {
  final Workout workout;
  final DateTime usualTime;
  final String reason;
  final bool isDueNow;
  final int confidence;

  const WorkoutReminder({
    required this.workout,
    required this.usualTime,
    required this.reason,
    required this.isDueNow,
    required this.confidence,
  });
}
