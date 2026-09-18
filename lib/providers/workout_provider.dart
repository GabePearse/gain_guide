import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/exercise.dart';
import '../models/set_entry.dart';
import '../models/workout.dart';
import '../models/workout_reminder.dart';
import '../services/supabase_data_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final SupabaseDataService _data = SupabaseDataService.instance;
  SupabaseClient get _supabase => Supabase.instance.client;

  AppUser? _currentUser;
  List<Workout> _workouts = [];
  List<Workout> _history = [];
  WorkoutReminder? _smartReminder;
  bool _isInitialized = false;

  AppUser? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isSignedIn => _currentUser != null;
  List<Workout> get workouts => List.unmodifiable(_workouts);
  List<Workout> get history => List.unmodifiable(_history);
  WorkoutReminder? get smartReminder => _smartReminder;

  AppUser? _appUserFromAuth() {
    final u = _supabase.auth.currentUser;
    if (u == null) return null;
    return AppUser(
      id: u.id.hashCode,
      displayName: (u.userMetadata?['display_name'] as String?) ?? u.email?.split('@').first ?? 'User',
      email: u.email ?? '',
      createdAt: DateTime.tryParse(u.createdAt) ?? DateTime.now(),
    );
  }

  Future<void> initialize() async {
    _currentUser = _appUserFromAuth();
    if (_currentUser != null) await _prepareSignedInUser();
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(email: email.trim(), password: password);
      _currentUser = _appUserFromAuth();
      await _prepareSignedInUser();
      notifyListeners();
      return true;
    } on AuthException {
      return false;
    }
  }

  Future<void> createAccount({required String displayName, required String email, required String password}) async {
    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
    _currentUser = response.user == null ? null : _appUserFromAuth();
    if (_currentUser != null && response.session != null) await _prepareSignedInUser();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _currentUser = null;
    _workouts = [];
    _history = [];
    _smartReminder = null;
    if (!kIsWeb) await NotificationService.instance.cancelSmartWorkoutReminder();
    notifyListeners();
  }

  Future<void> _prepareSignedInUser() async {
    await _seedInitialDataIfNeeded();
    await loadWorkouts();
    await loadHistory();
    _smartReminder = _buildSmartReminder();
    await _syncSmartNotification();
  }

  Future<void> loadWorkouts() async {
    if (_currentUser == null) return;
    _workouts = await _data.getWorkouts();
    _smartReminder = _buildSmartReminder();
    await _syncSmartNotification();
    notifyListeners();
  }

  Future<void> loadHistory() async {
    if (_currentUser == null) return;
    _history = await _data.getHistory();
    _smartReminder = _buildSmartReminder();
    await _syncSmartNotification();
    notifyListeners();
  }

  Future<void> addWorkout(String name) async {
    await _data.insertWorkout(name.trim());
    await loadWorkouts();
  }

  Future<void> renameWorkout(int workoutId, String newName) async {
    final workout = _workouts.where((w) => w.id == workoutId).firstOrNull;
    if (workout == null) {
      return;
    }

    await _data.updateWorkout(
      workout.copyWith(name: newName.trim()),
    );
    await loadWorkouts();
  }

  Future<void> scheduleWorkout({
    required int workoutId,
    required List<int> weekdays,
    required int hour,
    required int minute,
  }) async {
    final workout = getWorkoutById(workoutId);
    if (workout == null) return;
    final value = weekdays.toSet().toList()..sort();
    await _data.updateWorkout(workout.copyWith(
      scheduledWeekdays: value.join(','),
      scheduledHour: hour,
      scheduledMinute: minute,
    ));
    await loadWorkouts();
  }

  Future<void> deleteWorkout(int workoutId) async {
    await _data.deleteWorkout(workoutId);
    await loadWorkouts();
  }

  Future<void> addExercise(int workoutId, String exerciseName) async {
    await _data.insertExercise(
      Exercise(
        workoutId: workoutId,
        name: exerciseName.trim(),
      ),
    );
    await loadWorkouts();
  }

  Future<void> renameExercise(int exerciseId, String newName) async {
    Exercise? targetExercise;

    for (final workout in _workouts) {
      for (final exercise in workout.exercises) {
        if (exercise.id == exerciseId) {
          targetExercise = exercise;
          break;
        }
      }
      if (targetExercise != null) {
        break;
      }
    }

    if (targetExercise == null) {
      return;
    }

    await _data.updateExercise(
      targetExercise.copyWith(name: newName.trim()),
    );
    await loadWorkouts();
  }

  Future<void> deleteExercise(int exerciseId) async {
    await _data.deleteExercise(exerciseId);
    await loadWorkouts();
  }

  Future<void> logExerciseSet({
    required int exerciseId,
    required int reps,
    required double weight,
    int? restSeconds,
  }) async {
    await _data.insertSet(
      SetEntry(
        exerciseId: exerciseId,
        reps: reps,
        weight: weight,
        restSeconds: restSeconds,
      ),
    );

    await loadWorkouts();
  }

  Future<void> deleteSetEntry(int setEntryId) async {
    await _data.deleteSet(setEntryId);
    await loadWorkouts();
  }

  Future<void> completeWorkout(int workoutId) async {
    final workout = getWorkoutById(workoutId);
    if (workout == null) return;
    await _data.completeWorkout(workout);
    await loadWorkouts();
    await loadHistory();
    _smartReminder = _buildSmartReminder();
    await _syncSmartNotification();
  }

  Future<String> buildWorkoutExport({
    required DateTime start,
    required DateTime end,
  }) async {
    final allHistory = await _data.getHistory();
    final inclusiveEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    final workouts = allHistory.where((w) => w.completedAt != null && !w.completedAt!.isBefore(start) && !w.completedAt!.isAfter(inclusiveEnd)).toList();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final dayFormat = DateFormat('yyyy-MM-dd');
    final buffer = StringBuffer()
      ..writeln('GainGuide workout export')
      ..writeln('User: ${_currentUser?.displayName ?? 'Unknown'}')
      ..writeln('Range: ${dayFormat.format(start)} to ${dayFormat.format(end)}')
      ..writeln('Completed workouts: ${workouts.length}')
      ..writeln();

    if (workouts.isEmpty) {
      buffer.writeln('No workouts were completed in this date range.');
      return buffer.toString();
    }

    for (final workout in workouts) {
      final completedAt = workout.completedAt;
      buffer.writeln(
        '## ${workout.name} - '
        '${completedAt == null ? 'Unknown date' : dateFormat.format(completedAt)}',
      );

      if (workout.exercises.isEmpty) {
        buffer.writeln('- No exercises logged');
      }

      for (final exercise in workout.exercises) {
        buffer.writeln('- ${exercise.name}');
        if (exercise.sets.isEmpty) {
          buffer.writeln('  - No sets logged');
          continue;
        }

        for (var i = 0; i < exercise.sets.length; i++) {
          final set = exercise.sets[i];
          buffer.writeln(
            '  - Set ${i + 1}: ${set.weight.toStringAsFixed(1)} lbs x '
            '${set.reps} reps, volume '
            '${(set.weight * set.reps).toStringAsFixed(1)}',
          );
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  Workout? getWorkoutById(int workoutId) {
    try {
      return _workouts.firstWhere((workout) => workout.id == workoutId);
    } catch (_) {
      return null;
    }
  }

  Exercise? getExerciseById(int exerciseId) {
    for (final workout in _workouts) {
      for (final exercise in workout.exercises) {
        if (exercise.id == exerciseId) {
          return exercise;
        }
      }
    }

    return null;
  }

  WorkoutReminder? _buildSmartReminder() {
    if (_workouts.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final completedToday = _history.any((workout) {
      final completedAt = workout.completedAt;
      return completedAt != null &&
          completedAt.year == now.year &&
          completedAt.month == now.month &&
          completedAt.day == now.day;
    });

    if (completedToday) {
      return null;
    }

    final sameWeekday = _history
        .where((workout) => workout.completedAt?.weekday == now.weekday)
        .toList();
    final source = sameWeekday.isNotEmpty ? sameWeekday : _history;
    final predictedName = _mostCommonWorkoutName(source);
    final predictedWorkout = _workouts.firstWhereOrNull(
          (workout) => workout.name == predictedName,
        ) ??
        _workouts.first;
    final averageMinute = _averageMinuteOfDay(source);
    final usualTime = DateTime(
      now.year,
      now.month,
      now.day,
      averageMinute ~/ 60,
      averageMinute % 60,
    );
    final minutesFromUsual = now.difference(usualTime).inMinutes.abs();
    final confidence = source.isEmpty
        ? 35
        : (45 + (sameWeekday.length * 12)).clamp(45, 94).toInt();

    return WorkoutReminder(
      workout: predictedWorkout,
      usualTime: usualTime,
      reason: source.isEmpty
          ? 'No training pattern yet, so this is based on your first saved workout.'
          : sameWeekday.isNotEmpty
              ? 'You usually train ${predictedWorkout.name} around this time on this weekday.'
              : 'This is based on your recent training rhythm.',
      isDueNow: minutesFromUsual <= 90 || now.isAfter(usualTime),
      confidence: confidence,
    );
  }

  String? _mostCommonWorkoutName(List<Workout> workouts) {
    if (workouts.isEmpty) {
      return null;
    }

    final counts = <String, int>{};
    for (final workout in workouts) {
      counts[workout.name] = (counts[workout.name] ?? 0) + 1;
    }

    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  int _averageMinuteOfDay(List<Workout> workouts) {
    final completed = workouts
        .map((workout) => workout.completedAt)
        .whereType<DateTime>()
        .toList();

    if (completed.isEmpty) {
      return 18 * 60;
    }

    final totalMinutes = completed.fold<int>(
      0,
      (sum, date) => sum + (date.hour * 60) + date.minute,
    );
    return totalMinutes ~/ completed.length;
  }

  Future<void> _syncSmartNotification() async {
    if (kIsWeb) return;
    await NotificationService.instance.scheduleSmartWorkoutReminder(
      _smartReminder,
    );
    await NotificationService.instance.scheduleWorkoutPlan(
      workouts: _workouts,
      history: _history,
    );
  }

  String? progressiveOverloadAdvice(Exercise exercise) {
    for (final workout in _history) {
      for (final previous in workout.exercises) {
        if (previous.name.toLowerCase() != exercise.name.toLowerCase() || previous.sets.isEmpty) continue;
        final sets = previous.sets;
        final enoughSets = sets.length >= exercise.targetSets;
        final hitTopRange = enoughSets && sets.take(exercise.targetSets).every((set) => set.reps >= exercise.maxReps);
        final sameWeight = sets.take(exercise.targetSets).map((set) => set.weight).toSet().length == 1;
        final weight = sets.first.weight;
        if (hitTopRange && sameWeight) {
          return 'Last time: ${weight.toStringAsFixed(1)} lbs for ${sets.take(exercise.targetSets).map((s) => s.reps).join('/')} reps. Increase the weight this session.';
        }
        return 'Last time: ${sets.map((s) => '${s.weight.toStringAsFixed(1)}×${s.reps}').join(', ')}. Stay at the weight until you reach ${exercise.maxReps} reps on all ${exercise.targetSets} sets.';
      }
    }
    return null;
  }

  Future<void> _seedInitialDataIfNeeded() async {
    final existingWorkouts = await _data.getWorkouts();
    if (existingWorkouts.isNotEmpty) return;

    Future<int> workout(String name) => _data.insertWorkout(name);
    Future<void> exercise(int workoutId, String name, int sets, int min, int max, int restMin, int restMax) =>
        _data.insertExercise(Exercise(workoutId: workoutId, name: name, targetSets: sets, minReps: min, maxReps: max, restMinSeconds: restMin, restMaxSeconds: restMax));

    final upperA = await workout('Upper A');
    await exercise(upperA, 'Bench Press', 3, 8, 10, 120, 180);
    await exercise(upperA, 'Chest-Supported Row', 3, 8, 10, 120, 120);
    await exercise(upperA, 'Incline DB Press', 3, 8, 10, 120, 120);
    await exercise(upperA, 'Lat Pulldown', 3, 8, 10, 120, 120);
    await exercise(upperA, 'Cable Lateral Raise', 3, 10, 15, 60, 90);
    await exercise(upperA, 'Preacher Curl', 2, 8, 10, 90, 90);
    await exercise(upperA, 'Tricep Pushdown', 2, 8, 10, 90, 90);

    final lowerA = await workout('Lower A — Quad/Hip');
    await exercise(lowerA, 'Squat or Hack Squat', 3, 8, 10, 120, 180);
    await exercise(lowerA, 'Romanian Deadlift', 3, 8, 10, 120, 180);
    await exercise(lowerA, 'Bulgarian Split Squat', 3, 8, 10, 120, 120);
    await exercise(lowerA, 'Leg Extension', 2, 8, 10, 90, 90);
    await exercise(lowerA, 'Hip Abduction', 3, 12, 15, 60, 90);
    await exercise(lowerA, 'Calf Raise', 3, 10, 15, 90, 90);
    await exercise(lowerA, 'Cable Crunch', 3, 8, 12, 90, 90);

    final upperB = await workout('Upper B');
    await exercise(upperB, 'Incline DB Press', 3, 8, 10, 120, 180);
    await exercise(upperB, 'Lat Pulldown', 3, 8, 10, 120, 120);
    await exercise(upperB, 'Shoulder Press', 3, 8, 10, 120, 120);
    await exercise(upperB, 'Chest-Supported Row', 3, 8, 10, 120, 120);
    await exercise(upperB, 'Rear-Delt Fly', 3, 12, 15, 60, 90);
    await exercise(upperB, 'Face Pull', 2, 12, 15, 60, 90);
    await exercise(upperB, 'Hammer Curl', 2, 8, 10, 90, 90);
    await exercise(upperB, 'Overhead Tricep Extension', 2, 8, 10, 90, 90);

    final lowerB = await workout('Lower B — Posterior/Hip');
    await exercise(lowerB, 'Hip Thrust', 3, 8, 10, 120, 180);
    await exercise(lowerB, 'Leg Press', 3, 8, 10, 120, 180);
    await exercise(lowerB, 'Seated/Lying Leg Curl', 3, 8, 10, 90, 120);
    await exercise(lowerB, 'Walking Lunge', 2, 8, 10, 120, 120);
    await exercise(lowerB, 'Hip Adduction', 3, 12, 15, 60, 90);
    await exercise(lowerB, 'Hip Abduction', 2, 12, 15, 60, 90);
    await exercise(lowerB, 'Calf Raise', 3, 10, 15, 90, 90);
    await exercise(lowerB, 'Hanging Leg Raise', 3, 8, 12, 90, 90);

    final accessory = await workout('Accessory — Optional');
    await exercise(accessory, 'Cable Lateral Raise', 3, 12, 15, 60, 90);
    await exercise(accessory, 'Rear-Delt Fly', 2, 12, 15, 60, 90);
    await exercise(accessory, 'Preacher Curl', 3, 8, 10, 90, 90);
    await exercise(accessory, 'Hammer Curl', 2, 8, 10, 90, 90);
    await exercise(accessory, 'Tricep Pushdown', 3, 8, 10, 90, 90);
    await exercise(accessory, 'Overhead Tricep Extension', 2, 8, 10, 90, 90);
    await exercise(accessory, 'Cable Crunch', 3, 8, 12, 90, 90);
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;

  E? firstWhereOrNull(bool Function(E value) test) {
    for (final value in this) {
      if (test(value)) {
        return value;
      }
    }
    return null;
  }
}
