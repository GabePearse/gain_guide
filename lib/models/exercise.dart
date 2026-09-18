import 'set_entry.dart';

class Exercise {
  final int? id;
  final int workoutId;
  final String name;
  final List<SetEntry> sets;
  final int targetSets;
  final int minReps;
  final int maxReps;
  final int restMinSeconds;
  final int restMaxSeconds;
  final int sortOrder;

  const Exercise({
    this.id,
    required this.workoutId,
    required this.name,
    this.sets = const [],
    this.targetSets = 3,
    this.minReps = 8,
    this.maxReps = 10,
    this.restMinSeconds = 90,
    this.restMaxSeconds = 90,
    this.sortOrder = 0,
  });

  Exercise copyWith({
    int? id,
    int? workoutId,
    String? name,
    List<SetEntry>? sets,
    int? targetSets,
    int? minReps,
    int? maxReps,
    int? restMinSeconds,
    int? restMaxSeconds,
    int? sortOrder,
  }) {
    return Exercise(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      targetSets: targetSets ?? this.targetSets,
      minReps: minReps ?? this.minReps,
      maxReps: maxReps ?? this.maxReps,
      restMinSeconds: restMinSeconds ?? this.restMinSeconds,
      restMaxSeconds: restMaxSeconds ?? this.restMaxSeconds,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutId': workoutId,
      'name': name,
      'targetSets': targetSets,
      'minReps': minReps,
      'maxReps': maxReps,
      'restMinSeconds': restMinSeconds,
      'restMaxSeconds': restMaxSeconds,
      'sortOrder': sortOrder,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as int?,
      workoutId: map['workoutId'] as int,
      name: map['name'] as String,
      targetSets: (map['targetSets'] as int?) ?? 3,
      minReps: (map['minReps'] as int?) ?? 8,
      maxReps: (map['maxReps'] as int?) ?? 10,
      restMinSeconds: (map['restMinSeconds'] as int?) ?? 90,
      restMaxSeconds: (map['restMaxSeconds'] as int?) ?? 90,
      sortOrder: (map['sortOrder'] as int?) ?? 0,
    );
  }
}
