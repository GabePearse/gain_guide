class SetEntry {
  final int? id;
  final int exerciseId;
  final int reps;
  final double weight;
  final int? restSeconds;
  final DateTime? completedAt;

  const SetEntry({
    this.id,
    required this.exerciseId,
    required this.reps,
    required this.weight,
    this.restSeconds,
    this.completedAt,
  });

  SetEntry copyWith({
    int? id,
    int? exerciseId,
    int? reps,
    double? weight,
    int? restSeconds,
    DateTime? completedAt,
  }) {
    return SetEntry(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      restSeconds: restSeconds ?? this.restSeconds,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'reps': reps,
      'weight': weight,
      'restSeconds': restSeconds,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory SetEntry.fromMap(Map<String, dynamic> map) {
    return SetEntry(
      id: map['id'] as int?,
      exerciseId: map['exerciseId'] as int,
      reps: map['reps'] as int,
      weight: (map['weight'] as num).toDouble(),
      restSeconds: map['restSeconds'] as int?,
      completedAt: map['completedAt'] == null ? null : DateTime.parse(map['completedAt'] as String),
    );
  }
}
