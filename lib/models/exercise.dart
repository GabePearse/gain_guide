import 'set_entry.dart';

class Exercise {
  final int? id;
  final int workoutId;
  final String name;
  final List<SetEntry> sets;

  const Exercise({
    this.id,
    required this.workoutId,
    required this.name,
    this.sets = const [],
  });

  Exercise copyWith({
    int? id,
    int? workoutId,
    String? name,
    List<SetEntry>? sets,
  }) {
    return Exercise(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      name: name ?? this.name,
      sets: sets ?? this.sets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutId': workoutId,
      'name': name,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as int?,
      workoutId: map['workoutId'] as int,
      name: map['name'] as String,
    );
  }
}
