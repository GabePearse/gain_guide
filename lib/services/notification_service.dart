import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../app_navigation.dart';
import '../models/workout_reminder.dart';
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
