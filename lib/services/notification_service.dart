import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../app_navigation.dart';
import '../models/workout_reminder.dart';
import '../models/workout.dart';
import '../pages/log_exercises_page.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();
  static const int smartWorkoutReminderId = 7001;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  int? _pendingWorkoutId;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    tz.initializeTimeZones();
    await _setLocalTimeZone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    await _requestPermissions();
    final launchDetails =
        await _notifications.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        response != null) {
      _handleNotificationResponse(response);
    }

    _isInitialized = true;
  }

  Future<void> scheduleSmartWorkoutReminder(
    WorkoutReminder? reminder,
  ) async {
    await initialize();

    if (reminder == null || reminder.workout.id == null) {
      await cancelSmartWorkoutReminder();
      return;
    }

    final scheduledTime = _nextInstanceOfTime(reminder.usualTime);
    await _notifications.zonedSchedule(
      id: smartWorkoutReminderId,
      title: 'Time for ${reminder.workout.name}',
      body:
          'GainGuide predicted this is your usual training window. Tap to start.',
      scheduledDate: scheduledTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_workout_reminders',
          'Smart workout reminders',
          channelDescription:
              'Workout reminders based on your usual training pattern.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'workout:${reminder.workout.id}',
    );
  }

  Future<void> cancelSmartWorkoutReminder() async {
    await _notifications.cancel(id: smartWorkoutReminderId);
  }


  Future<void> scheduleWorkoutPlan({
    required List<Workout> workouts,
    required List<Workout> history,
  }) async {
    await initialize();
    for (final workout in workouts) {
      final id = workout.id;
      if (id == null) continue;
      await _notifications.cancel(id: 8000 + id);
      await _notifications.cancel(id: 9000 + id);
      final weekdays = workout.scheduledWeekdays
          ?.split(',').map(int.tryParse).whereType<int>().toList() ?? const <int>[];
      if (weekdays.isEmpty || workout.scheduledHour == null || workout.scheduledMinute == null) continue;
      final next = _nextScheduledDay(weekdays, workout.scheduledHour!, workout.scheduledMinute!, workout.name, history);
      await _notifications.zonedSchedule(
        id: 8000 + id,
        title: '${workout.name} is scheduled today',
        body: 'Tap to start your workout.',
        scheduledDate: next,
        notificationDetails: _plannedDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'workout:$id',
      );
      final missed = tz.TZDateTime(tz.local, next.year, next.month, next.day, 21);
      if (missed.isAfter(tz.TZDateTime.now(tz.local))) {
        await _notifications.zonedSchedule(
          id: 9000 + id,
          title: 'You missed ${workout.name}',
          body: 'Your scheduled workout has not been logged today. Tap to get back on track.',
          scheduledDate: missed,
          notificationDetails: _plannedDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'workout:$id',
        );
      }
    }
  }

  static const NotificationDetails _plannedDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'planned_workouts', 'Planned workouts',
      channelDescription: 'Scheduled workout and missed-day reminders.',
      importance: Importance.high, priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  tz.TZDateTime _nextScheduledDay(List<int> weekdays, int hour, int minute, String workoutName, List<Workout> history) {
    final now = tz.TZDateTime.now(tz.local);
    for (var offset = 0; offset <= 7; offset++) {
      final day = now.add(Duration(days: offset));
      if (!weekdays.contains(day.weekday)) continue;
      final candidate = tz.TZDateTime(tz.local, day.year, day.month, day.day, hour, minute);
      final completed = history.any((w) => w.name == workoutName && w.completedAt != null &&
          w.completedAt!.year == day.year && w.completedAt!.month == day.month && w.completedAt!.day == day.day);
      if (!completed && candidate.isAfter(now)) return candidate;
    }
    final target = now.add(const Duration(days: 7));
    return tz.TZDateTime(tz.local, target.year, target.month, target.day, hour, minute);
  }
  int? consumePendingWorkoutId() {
    final workoutId = _pendingWorkoutId;
    _pendingWorkoutId = null;
    return workoutId;
  }

  Future<void> _setLocalTimeZone() async {
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      final timeZoneName = timeZone.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final mac = _notifications.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    await mac?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(DateTime time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.startsWith('workout:')) {
      return;
    }

    final workoutId = int.tryParse(payload.substring('workout:'.length));
    if (workoutId == null) {
      return;
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _pendingWorkoutId = workoutId;
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => LogExercisesPage(workoutId: workoutId),
      ),
    );
  }
}
