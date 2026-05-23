class SetEntry {
  final int? id;
  final int exerciseId;
  final int reps;
  final double weight;

  const SetEntry({
    this.id,
    required this.exerciseId,
    required this.reps,
    required this.weight,
  });

  SetEntry copyWith({
    int? id,
    int? exerciseId,
    int? reps,
    double? weight,
  }) {
    return SetEntry(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'reps': reps,
      'weight': weight,
    };
  }

  factory SetEntry.fromMap(Map<String, dynamic> map) {
    return SetEntry(
      id: map['id'] as int?,
      exerciseId: map['exerciseId'] as int,
      reps: map['reps'] as int,
      weight: (map['weight'] as num).toDouble(),
    );
  }
}
