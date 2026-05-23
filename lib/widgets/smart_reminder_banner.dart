import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/workout_provider.dart';
import '../pages/log_exercises_page.dart';

class SmartReminderBanner extends StatefulWidget {
  const SmartReminderBanner({super.key});

  @override
  State<SmartReminderBanner> createState() => _SmartReminderBannerState();
}

class _SmartReminderBannerState extends State<SmartReminderBanner> {
  int? _shownForWorkoutId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reminder = context.watch<WorkoutProvider>().smartReminder;
    final workoutId = reminder?.workout.id;

    if (reminder == null ||
        !reminder.isDueNow ||
        workoutId == null ||
        _shownForWorkoutId == workoutId) {
      return;
    }

    _shownForWorkoutId = workoutId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentMaterialBanner();
      messenger.showMaterialBanner(
        MaterialBanner(
          leading: const Icon(Icons.notifications_active_outlined),
          content: Text(
            '${reminder.workout.name} usually starts around '
            '${DateFormat('h:mm a').format(reminder.usualTime)}.',
          ),
          actions: [
            TextButton(
              onPressed: () => messenger.hideCurrentMaterialBanner(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LogExercisesPage(workoutId: workoutId),
                  ),
                );
              },
              child: const Text('Start'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
