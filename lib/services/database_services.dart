import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_user.dart';
import '../models/exercise.dart';
import '../models/friend_reminder.dart';
import '../models/friend_summary.dart';
import '../models/set_entry.dart';
import '../models/workout.dart';

class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService instance = DatabaseService._internal();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gain_guide.db');

    return openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createBaseTables(db);
        await _createHistoryTables(db);
        await _createSocialTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createHistoryTables(db);
          await _migrateLegacyCompletedHistory(db);
        }

        if (oldVersion < 3) {
          await _addColumnIfMissing(db, 'workouts', 'userId', 'INTEGER');
          await _addColumnIfMissing(
            db,
            'completed_workouts',
            'userId',
            'INTEGER',
          );
          await _createSocialTables(db);
        }
      },
    );
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _createBaseTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        name TEXT NOT NULL,
        completedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutId INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (workoutId) REFERENCES workouts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE set_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exerciseId INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        FOREIGN KEY (exerciseId) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createHistoryTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS completed_workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        name TEXT NOT NULL,
        completedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS completed_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutId INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (workoutId) REFERENCES completed_workouts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS completed_set_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exerciseId INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        FOREIGN KEY (exerciseId) REFERENCES completed_exercises(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createSocialTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        displayName TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        lastCheckInAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS active_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        userId INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS friends (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ownerUserId INTEGER NOT NULL,
        friendUserId INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        UNIQUE(ownerUserId, friendUserId),
        FOREIGN KEY (ownerUserId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (friendUserId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS friend_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fromUserId INTEGER NOT NULL,
        toUserId INTEGER NOT NULL,
        message TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        readAt TEXT,
        FOREIGN KEY (fromUserId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (toUserId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _migrateLegacyCompletedHistory(Database db) async {
    final legacyCompletedWorkouts = await db.query(
      'workouts',
      where: 'completedAt IS NOT NULL',
      orderBy: 'completedAt ASC',
    );

    for (final workoutMap in legacyCompletedWorkouts) {
      final legacyWorkoutId = workoutMap['id'] as int;
      final completedAt = workoutMap['completedAt'] as String?;
      final workoutName = workoutMap['name'] as String;

      if (completedAt == null) {
        continue;
      }

      final completedWorkoutId = await db.insert(
        'completed_workouts',
        {
          'name': workoutName,
          'completedAt': completedAt,
        },
      );

      await _copyExercises(
        executor: db,
        sourceWorkoutId: legacyWorkoutId,
        targetWorkoutId: completedWorkoutId,
        sourceExerciseTable: 'exercises',
        sourceSetTable: 'set_entries',
        targetExerciseTable: 'completed_exercises',
        targetSetTable: 'completed_set_entries',
      );

      await db.rawDelete(
        '''
        DELETE FROM set_entries
        WHERE exerciseId IN (
          SELECT id FROM exercises WHERE workoutId = ?
        )
        ''',
        [legacyWorkoutId],
      );

      await db.update(
        'workouts',
        {'completedAt': null},
        where: 'id = ?',
        whereArgs: [legacyWorkoutId],
      );
    }
  }

  Future<AppUser?> getActiveUser() async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT u.*
      FROM active_session s
      JOIN users u ON u.id = s.userId
      WHERE s.id = 1
      LIMIT 1
      ''',
    );

    if (rows.isEmpty) {
      return null;
    }

    return AppUser.fromMap(rows.first);
  }

  Future<AppUser> createUser({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final db = await database;
    final normalizedEmail = email.trim().toLowerCase();
    final now = DateTime.now().toIso8601String();

    final userId = await db.insert(
      'users',
      {
        'displayName': displayName.trim(),
        'email': normalizedEmail,
        'password': password,
        'createdAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    await setActiveUser(userId);
    final user = await getUserById(userId);
    return user!;
  }

  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email.trim().toLowerCase(), password],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final user = AppUser.fromMap(rows.first);
    await setActiveUser(user.id!);
    return user;
  }

  Future<AppUser> getOrCreateExternalUser({
    required String displayName,
    required String email,
    required String provider,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final existingUser = await _getUserByEmail(normalizedEmail);

    if (existingUser != null) {
      await setActiveUser(existingUser.id!);
      return existingUser;
    }

    final user = await createUser(
      displayName: displayName.trim().isEmpty
          ? normalizedEmail.split('@').first
          : displayName.trim(),
      email: normalizedEmail,
      password: 'external:$provider',
    );
    return user;
  }

  Future<AppUser?> getUserById(int userId) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return AppUser.fromMap(rows.first);
  }

  Future<void> setActiveUser(int userId) async {
    final db = await database;
    await db.insert(
      'active_session',
      {'id': 1, 'userId': userId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> signOut() async {
    final db = await database;
    await db.delete('active_session', where: 'id = 1');
  }

  Future<void> claimLegacyData(int userId) async {
    final db = await database;
    await db.update(
      'workouts',
      {'userId': userId},
      where: 'userId IS NULL',
    );
    await db.update(
      'completed_workouts',
      {'userId': userId},
      where: 'userId IS NULL',
    );
  }

  Future<void> updateUserCheckIn(int userId) async {
    final db = await database;
    await db.update(
      'users',
      {'lastCheckInAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> insertWorkout(Workout workout) async {
    final db = await database;
    return db.insert('workouts', workout.toMap());
  }

  Future<List<Workout>> getWorkouts({required int userId}) async {
    return _getWorkoutsFromTable(
      workoutTable: 'workouts',
      exerciseTable: 'exercises',
      setTable: 'set_entries',
      orderBy: 'name COLLATE NOCASE ASC',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<int> updateWorkout(Workout workout) async {
    final db = await database;
    return db.update(
      'workouts',
      workout.toMap(),
      where: 'id = ?',
      whereArgs: [workout.id],
    );
  }

  Future<int> deleteWorkout(int workoutId) async {
    final db = await database;
    return db.delete(
      'workouts',
      where: 'id = ?',
      whereArgs: [workoutId],
    );
  }

  Future<int> insertExercise(Exercise exercise) async {
    final db = await database;
    return db.insert('exercises', exercise.toMap());
  }

  Future<int> updateExercise(Exercise exercise) async {
    final db = await database;
    return db.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<int> deleteExercise(int exerciseId) async {
    final db = await database;
    return db.delete(
      'exercises',
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
  }

  Future<int> insertSetEntry(SetEntry setEntry) async {
    final db = await database;
    return db.insert('set_entries', setEntry.toMap());
  }

  Future<int> deleteSetEntry(int setEntryId) async {
    final db = await database;
    return db.delete(
      'set_entries',
      where: 'id = ?',
      whereArgs: [setEntryId],
    );
  }

  Future<List<Workout>> getHistory({required int userId}) async {
    return _getWorkoutsFromTable(
      workoutTable: 'completed_workouts',
      exerciseTable: 'completed_exercises',
      setTable: 'completed_set_entries',
      orderBy: 'completedAt DESC',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<List<Workout>> getHistoryForRange({
    required int userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final inclusiveEnd = DateTime(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
      999,
    );

    return _getWorkoutsFromTable(
      workoutTable: 'completed_workouts',
      exerciseTable: 'completed_exercises',
      setTable: 'completed_set_entries',
      orderBy: 'completedAt ASC',
      where: 'userId = ? AND completedAt >= ? AND completedAt <= ?',
      whereArgs: [
        userId,
        DateTime(start.year, start.month, start.day).toIso8601String(),
        inclusiveEnd.toIso8601String(),
      ],
    );
  }

  Future<void> completeWorkout({
    required Workout workout,
    required int userId,
  }) async {
    final db = await database;
    final completedAt = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final completedWorkoutId = await txn.insert(
        'completed_workouts',
        {
          'userId': userId,
          'name': workout.name,
          'completedAt': completedAt,
        },
      );

      await _copyWorkoutExercisesToCompleted(
        executor: txn,
        workout: workout,
        targetWorkoutId: completedWorkoutId,
      );

      await txn.rawDelete(
        '''
        DELETE FROM set_entries
        WHERE exerciseId IN (
          SELECT id FROM exercises WHERE workoutId = ?
        )
        ''',
        [workout.id],
      );

      await txn.update(
        'workouts',
        {'completedAt': null},
        where: 'id = ?',
        whereArgs: [workout.id],
      );

      await txn.update(
        'users',
        {'lastCheckInAt': completedAt},
        where: 'id = ?',
        whereArgs: [userId],
      );
    });
  }

  Future<List<FriendSummary>> getFriends(int ownerUserId) async {
    final db = await database;
    final friendRows = await db.rawQuery(
      '''
      SELECT u.*
      FROM friends f
      JOIN users u ON u.id = f.friendUserId
      WHERE f.ownerUserId = ?
      ORDER BY u.displayName COLLATE NOCASE ASC
      ''',
      [ownerUserId],
    );

    final summaries = <FriendSummary>[];

    for (final row in friendRows) {
      final user = AppUser.fromMap(row);
      final friendId = user.id!;
      final completedCount = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM completed_workouts WHERE userId = ?',
              [friendId],
            ),
          ) ??
          0;
      final latestRows = await db.query(
        'completed_workouts',
        where: 'userId = ?',
        whereArgs: [friendId],
        orderBy: 'completedAt DESC',
        limit: 1,
      );
      final unreadCount = Sqflite.firstIntValue(
            await db.rawQuery(
              '''
              SELECT COUNT(*)
              FROM friend_reminders
              WHERE fromUserId = ? AND toUserId = ? AND readAt IS NULL
              ''',
              [friendId, ownerUserId],
            ),
          ) ??
          0;

      summaries.add(
        FriendSummary(
          friendUserId: friendId,
          displayName: user.displayName,
          email: user.email,
          lastCheckInAt: user.lastCheckInAt,
          completedWorkouts: completedCount,
          lastWorkoutName: latestRows.isEmpty
              ? null
              : latestRows.first['name'] as String?,
          lastWorkoutAt: latestRows.isEmpty
              ? null
              : DateTime.parse(latestRows.first['completedAt'] as String),
          unreadReminders: unreadCount,
        ),
      );
    }

    return summaries;
  }

  Future<void> addFriend({
    required int ownerUserId,
    required String displayName,
    required String email,
  }) async {
    final db = await database;
    final normalizedEmail = email.trim().toLowerCase();
    final owner = await getUserById(ownerUserId);
    if (owner?.email == normalizedEmail) {
      throw StateError('You cannot add yourself as a friend.');
    }

    AppUser? friend = await _getUserByEmail(normalizedEmail);
    friend ??= await _createPlaceholderFriend(
      displayName: displayName,
      email: normalizedEmail,
    );

    await db.insert(
      'friends',
      {
        'ownerUserId': ownerUserId,
        'friendUserId': friend.id!,
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> seedDemoFriendsIfNeeded(int ownerUserId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM friends WHERE ownerUserId = ?',
            [ownerUserId],
          ),
        ) ??
        0;

    if (count > 0) {
      return;
    }

    await addFriend(
      ownerUserId: ownerUserId,
      displayName: 'Maya',
      email: 'maya.training@example.com',
    );
    await addFriend(
      ownerUserId: ownerUserId,
      displayName: 'Jordan',
      email: 'jordan.lifts@example.com',
    );
    await addFriend(
      ownerUserId: ownerUserId,
      displayName: 'Sam',
      email: 'sam.strength@example.com',
    );
  }

  Future<void> sendReminder({
    required int fromUserId,
    required int toUserId,
    required String message,
  }) async {
    final db = await database;
    await db.insert(
      'friend_reminders',
      {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'message': message.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<FriendReminder>> getReminders(int userId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT r.*, fromUser.displayName AS fromName, toUser.displayName AS toName
      FROM friend_reminders r
      JOIN users fromUser ON fromUser.id = r.fromUserId
      JOIN users toUser ON toUser.id = r.toUserId
      WHERE r.fromUserId = ? OR r.toUserId = ?
      ORDER BY r.createdAt DESC
      ''',
      [userId, userId],
    );

    return rows.map(FriendReminder.fromMap).toList();
  }

  Future<void> markReceivedRemindersRead(int userId) async {
    final db = await database;
    await db.update(
      'friend_reminders',
      {'readAt': DateTime.now().toIso8601String()},
      where: 'toUserId = ? AND readAt IS NULL',
      whereArgs: [userId],
    );
  }

  Future<AppUser?> _getUserByEmail(String email) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return AppUser.fromMap(rows.first);
  }

  Future<AppUser> _createPlaceholderFriend({
    required String displayName,
    required String email,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final friendId = await db.insert(
      'users',
      {
        'displayName': displayName.trim().isEmpty
            ? email.split('@').first
            : displayName.trim(),
        'email': email,
        'password': 'friend-placeholder',
        'createdAt': now.toIso8601String(),
        'lastCheckInAt': now
            .subtract(Duration(days: (email.hashCode.abs() % 5) + 1))
            .toIso8601String(),
      },
    );

    await _seedDemoHistoryForFriend(friendId);
    return (await getUserById(friendId))!;
  }

  Future<void> _seedDemoHistoryForFriend(int friendId) async {
    final db = await database;
    final templates = [
      ('Upper Body', 'Bench Press', 135.0),
      ('Leg Day', 'Squat', 185.0),
      ('Pull Session', 'Lat Pulldown', 120.0),
    ];

    for (var i = 0; i < templates.length; i++) {
      final template = templates[i];
      final completedWorkoutId = await db.insert(
        'completed_workouts',
        {
          'userId': friendId,
          'name': template.$1,
          'completedAt': DateTime.now()
              .subtract(Duration(days: i * 3 + 1))
              .toIso8601String(),
        },
      );
      final exerciseId = await db.insert(
        'completed_exercises',
        {
          'workoutId': completedWorkoutId,
          'name': template.$2,
        },
      );

      for (var setIndex = 0; setIndex < 3; setIndex++) {
        await db.insert(
          'completed_set_entries',
          {
            'exerciseId': exerciseId,
            'reps': 8 + setIndex,
            'weight': template.$3 + (setIndex * 5),
          },
        );
      }
    }
  }

  Future<void> _copyWorkoutExercisesToCompleted({
    required DatabaseExecutor executor,
    required Workout workout,
    required int targetWorkoutId,
  }) async {
    for (final exercise in workout.exercises) {
      final completedExerciseId = await executor.insert(
        'completed_exercises',
        {
          'workoutId': targetWorkoutId,
          'name': exercise.name,
        },
      );

      for (final setEntry in exercise.sets) {
        await executor.insert(
          'completed_set_entries',
          {
            'exerciseId': completedExerciseId,
            'reps': setEntry.reps,
            'weight': setEntry.weight,
          },
        );
      }
    }
  }

  Future<void> _copyExercises({
    required DatabaseExecutor executor,
    required int sourceWorkoutId,
    required int targetWorkoutId,
    required String sourceExerciseTable,
    required String sourceSetTable,
    required String targetExerciseTable,
    required String targetSetTable,
  }) async {
    final exerciseMaps = await executor.query(
      sourceExerciseTable,
      where: 'workoutId = ?',
      whereArgs: [sourceWorkoutId],
      orderBy: 'id ASC',
    );

    for (final exerciseMap in exerciseMaps) {
      final sourceExerciseId = exerciseMap['id'] as int;
      final targetExerciseId = await executor.insert(
        targetExerciseTable,
        {
          'workoutId': targetWorkoutId,
          'name': exerciseMap['name'] as String,
        },
      );

      final setMaps = await executor.query(
        sourceSetTable,
        where: 'exerciseId = ?',
        whereArgs: [sourceExerciseId],
        orderBy: 'id ASC',
      );

      for (final setMap in setMaps) {
        await executor.insert(
          targetSetTable,
          {
            'exerciseId': targetExerciseId,
            'reps': setMap['reps'] as int,
            'weight': (setMap['weight'] as num).toDouble(),
          },
        );
      }
    }
  }

  Future<List<Workout>> _getWorkoutsFromTable({
    required String workoutTable,
    required String exerciseTable,
    required String setTable,
    required String orderBy,
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    final workoutMaps = await db.query(
      workoutTable,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );

    final workouts = <Workout>[];

    for (final workoutMap in workoutMaps) {
      final workout = Workout.fromMap(workoutMap);
      final exercises = await _getExercisesForWorkoutFromTable(
        workoutId: workout.id!,
        exerciseTable: exerciseTable,
        setTable: setTable,
      );

      workouts.add(
        workout.copyWith(exercises: exercises),
      );
    }

    return workouts;
  }

  Future<List<Exercise>> _getExercisesForWorkoutFromTable({
    required int workoutId,
    required String exerciseTable,
    required String setTable,
  }) async {
    final db = await database;
    final exerciseMaps = await db.query(
      exerciseTable,
      where: 'workoutId = ?',
      whereArgs: [workoutId],
      orderBy: 'id ASC',
    );

    final exercises = <Exercise>[];

    for (final exerciseMap in exerciseMaps) {
      final exercise = Exercise.fromMap(exerciseMap);
      final sets = await _getSetEntriesForExerciseFromTable(
        exerciseId: exercise.id!,
        setTable: setTable,
      );

      exercises.add(
        exercise.copyWith(sets: sets),
      );
    }

    return exercises;
  }

  Future<List<SetEntry>> _getSetEntriesForExerciseFromTable({
    required int exerciseId,
    required String setTable,
  }) async {
    final db = await database;
    final setMaps = await db.query(
      setTable,
      where: 'exerciseId = ?',
      whereArgs: [exerciseId],
      orderBy: 'id ASC',
    );

    return setMaps.map(SetEntry.fromMap).toList();
  }
}
