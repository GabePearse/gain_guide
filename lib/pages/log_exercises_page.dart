import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/workout_provider.dart';
import '../widgets/exercise_tile.dart';
import '../widgets/rest_timer_card.dart';
import 'log_workout_page.dart';

class LogExercisesPage extends StatelessWidget {
  final int workoutId;

  const LogExercisesPage({
    required this.workoutId,
    super.key,
  });

  int _totalLoggedSetsForWorkout(Iterable exercises) {
    int total = 0;

    for (final exercise in exercises) {
      total += exercise.sets.length as int;
    }

    return total;
  }

  Future<void> _confirmCompleteWorkout(
    BuildContext context,
    String workoutName,
    int totalSets,
  ) async {
    final shouldComplete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Finish Workout'),
              content: Text(
                'Complete "$workoutName" with $totalSets logged '
                '${totalSets == 1 ? 'set' : 'sets'}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Finish'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldComplete || !context.mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await context.read<WorkoutProvider>().completeWorkout(workoutId);

    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(
      SnackBar(content: Text('"$workoutName" saved to history')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final workout = provider.getWorkoutById(workoutId);

    if (workout == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Log Workout')),
        body: const Center(
          child: Text('Workout not found.'),
        ),
      );
    }

    final totalLoggedSets = _totalLoggedSetsForWorkout(workout.exercises);
    final hasLoggedSets = totalLoggedSets > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Log ${workout.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _WorkoutStat(
                        label: 'Exercises',
                        value: '${workout.exercises.length}',
                      ),
                    ),
                    Expanded(
                      child: _WorkoutStat(
                        label: 'Logged Sets',
                        value: '$totalLoggedSets',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const RestTimerCard(),
            const SizedBox(height: 12),
            Expanded(
              child: workout.exercises.isEmpty
                  ? const Center(
                      child: Text('No exercises found for this workout.'),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: workout.exercises.length,
                      onReorderItem: (oldIndex, newIndex) {
                        context.read<WorkoutProvider>().reorderExercises(workoutId, oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final exercise = workout.exercises[index];
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(exercise.id),
                          index: index,
                          child: ExerciseTile(
                          name: exercise.name,
                          setCount: exercise.sets.length,
                          onTap: exercise.id == null
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LogWorkoutPage(
                                        workoutId: workoutId,
                                        exerciseId: exercise.id!,
                                      ),
                                    ),
                                  );
                                },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: hasLoggedSets
                    ? () => _confirmCompleteWorkout(
                          context,
                          workout.name,
                          totalLoggedSets,
                        )
                    : null,
                child: const Text('End Workout'),
              ),
            ),
            if (!hasLoggedSets) ...[
              const SizedBox(height: 8),
              const Text(
                'Log at least one set before finishing the workout.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkoutStat extends StatelessWidget {
  final String label;
  final String value;

  const _WorkoutStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          value,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}
