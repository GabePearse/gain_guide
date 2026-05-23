import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/exercise.dart';
import '../models/friend_reminder.dart';
import '../models/friend_summary.dart';
import '../models/set_entry.dart';
import '../models/workout.dart';
import '../models/workout_reminder.dart';
import '../services/database_services.dart';
import '../services/external_auth_service.dart';
import '../services/notification_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  AppUser? _currentUser;
  List<Workout> _workouts = [];
  List<Workout> _history = [];
  List<FriendSummary> _friends = [];
  List<FriendReminder> _reminders = [];
  WorkoutReminder? _smartReminder;
  bool _isInitialized = false;

  AppUser? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isSignedIn => _currentUser != null;
  List<Workout> get workouts => List.unmodifiable(_workouts);
  List<Workout> get history => List.unmodifiable(_history);
  List<FriendSummary> get friends => List.unmodifiable(_friends);
  List<FriendReminder> get reminders => List.unmodifiable(_reminders);
  WorkoutReminder? get smartReminder => _smartReminder;

  Future<void> initialize() async {
    _currentUser = await _databaseService.getActiveUser();
    if (_currentUser != null) {
      await _prepareSignedInUser();
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final user = await _databaseService.signIn(
      email: email,
      password: password,
    );

    if (user == null) {
      return false;
    }

    _currentUser = user;
    await _prepareSignedInUser();
    notifyListeners();
    return true;
  }

  Future<void> createAccount({
    required String displayName,
    required String email,
    required String password,
  }) async {
    _currentUser = await _databaseService.createUser(
      displayName: displayName,
      email: email,
      password: password,
    );
    await _prepareSignedInUser();
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    final profile = await ExternalAuthService.instance.signInWithGoogle();
    _currentUser = await _databaseService.getOrCreateExternalUser(
      displayName: profile.displayName,
      email: profile.email,
      provider: profile.provider,
    );
    await _prepareSignedInUser();
    notifyListeners();
  }

  Future<void> signInWithApple() async {
    final profile = await ExternalAuthService.instance.signInWithApple();
    _currentUser = await _databaseService.getOrCreateExternalUser(
      displayName: profile.displayName,
      email: profile.email,
      provider: profile.provider,
    );
    await _prepareSignedInUser();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _databaseService.signOut();
    _currentUser = null;
    _workouts = [];
    _history = [];
    _friends = [];
    _reminders = [];
    _smartReminder = null;
    await NotificationService.instance.cancelSmartWorkoutReminder();
    notifyListeners();
  }

  Future<void> _prepareSignedInUser() async {
    final userId = _requireUserId();
    await _databaseService.claimLegacyData(userId);
    await _seedInitialDataIfNeeded();
    await _databaseService.seedDemoFriendsIfNeeded(userId);
    await loadWorkouts();
    await loadHistory();
    await loadFriends();
    await loadReminders();
    _smartReminder = _buildSmartReminder();
    await _syncSmartNotification();
  }

  Future<void> loadWorkouts() async {
    if (_currentUser == null) return;
    _workouts = await _databaseService.getWorkouts(userId: _requireUserId());
    _smartReminder = _buildSmartReminder();
    await _syncSmartNotification();
    notifyListeners();
  }

  Future<void> loadHistory() async {
    if (_currentUser == null) return;
    _history = await _databaseService.getHistory(userId: _requireUserId());
    _smartReminder = _buildSmartReminder();
    await _syncSmartNotification();
    notifyListeners();
  }

  Future<void> loadFriends() async {
    if (_currentUser == null) return;
    _friends = await _databaseService.getFriends(_requireUserId());
    notifyListeners();
  }

  Future<void> loadReminders() async {
    if (_currentUser == null) return;
    _reminders = await _databaseService.getReminders(_requireUserId());
    notifyListeners();
  }

  Future<void> addFriend({
    required String displayName,
    required String email,
  }) async {
    await _databaseService.addFriend(
      ownerUserId: _requireUserId(),
      displayName: displayName,
      email: email,
    );
    await loadFriends();
  }

  Future<void> sendReminder({
    required int friendUserId,
    required String message,
  }) async {
    await _databaseService.sendReminder(
      fromUserId: _requireUserId(),
      toUserId: friendUserId,
      message: message,
    );
    await loadReminders();
  }

  Future<void> markRemindersRead() async {
    await _databaseService.markReceivedRemindersRead(_requireUserId());
    await loadFriends();
    await loadReminders();
  }

  Future<void> checkInNow() async {
    final userId = _requireUserId();
    await _databaseService.updateUserCheckIn(userId);
    _currentUser = await _databaseService.getUserById(userId);
    notifyListeners();
  }

  Future<void> addWorkout(String name) async {
    await _databaseService.insertWorkout(
      Workout(
        userId: _requireUserId(),
        name: name.trim(),
      ),
    );
    await loadWorkouts();
  }

  Future<void> renameWorkout(int workoutId, String newName) async {
    final workout = _workouts.where((w) => w.id == workoutId).firstOrNull;
    if (workout == null) {
      return;
    }

    await _databaseService.updateWorkout(
      workout.copyWith(name: newName.trim()),
    );
    await loadWorkouts();
  }

  Future<void> deleteWorkout(int workoutId) async {
    await _databaseService.deleteWorkout(workoutId);
    await loadWorkouts();
  }

  Future<void> addExercise(int workoutId, String exerciseName) async {
    await _databaseService.insertExercise(
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

    await _databaseService.updateExercise(
      targetExercise.copyWith(name: newName.trim()),
    );
    await loadWorkouts();
  }

  Future<void> deleteExercise(int exerciseId) async {
    await _databaseService.deleteExercise(exerciseId);
    await loadWorkouts();
  }

  Future<void> logExerciseSet({
    required int exerciseId,
    required int reps,
    required double weight,
  }) async {
    await _databaseService.insertSetEntry(
      SetEntry(
        exerciseId: exerciseId,
        reps: reps,
        weight: weight,
      ),
    );

    await loadWorkouts();
  }

  Future<void> deleteSetEntry(int setEntryId) async {
    await _databaseService.deleteSetEntry(setEntryId);
    await loadWorkouts();
  }

  Future<void> completeWorkout(int workoutId) async {
    final workout = _workouts.where((w) => w.id == workoutId).firstOrNull;
    if (workout == null) {
      return;
    }

    await _databaseService.completeWorkout(
      workout: workout,
      userId: _requireUserId(),
    );

    _currentUser = await _databaseService.getUserById(_requireUserId());
    await loadWorkouts();
    await loadHistory();
    await loadFriends();
    _smartReminder = _buildSmartReminder();
    await _syncSmartNotification();
  }

  Future<String> buildWorkoutExport({
    required DateTime start,
    required DateTime end,
  }) async {
    final workouts = await _databaseService.getHistoryForRange(
      userId: _requireUserId(),
      start: start,
      end: end,
    );
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
    await NotificationService.instance.scheduleSmartWorkoutReminder(
      _smartReminder,
    );
  }

  int _requireUserId() {
    final userId = _currentUser?.id;
    if (userId == null) {
      throw StateError('A signed-in user is required.');
    }
    return userId;
  }

  Future<void> _seedInitialDataIfNeeded() async {
    final userId = _requireUserId();
    final existingWorkouts = await _databaseService.getWorkouts(userId: userId);
    if (existingWorkouts.isNotEmpty) {
      return;
    }

    final pushDayId = await _databaseService.insertWorkout(
      Workout(userId: userId, name: 'Push Day'),
    );
    final pullDayId = await _databaseService.insertWorkout(
      Workout(userId: userId, name: 'Pull Day'),
    );
    final legsId = await _databaseService.insertWorkout(
      Workout(userId: userId, name: 'Legs'),
    );

    await _databaseService.insertExercise(
      Exercise(workoutId: pushDayId, name: 'Bench Press'),
    );
    await _databaseService.insertExercise(
      Exercise(workoutId: pushDayId, name: 'Incline DB Press'),
    );
    await _databaseService.insertExercise(
      Exercise(workoutId: pushDayId, name: 'Tricep Pushdown'),
    );

    await _databaseService.insertExercise(
      Exercise(workoutId: pullDayId, name: 'Lat Pulldown'),
    );
    await _databaseService.insertExercise(
      Exercise(workoutId: pullDayId, name: 'Barbell Row'),
    );
    await _databaseService.insertExercise(
      Exercise(workoutId: pullDayId, name: 'Hammer Curl'),
    );

    await _databaseService.insertExercise(
      Exercise(workoutId: legsId, name: 'Squat'),
    );
    await _databaseService.insertExercise(
      Exercise(workoutId: legsId, name: 'Leg Press'),
    );
    await _databaseService.insertExercise(
      Exercise(workoutId: legsId, name: 'Leg Curl'),
    );
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
