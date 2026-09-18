import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/workout_provider.dart';
import '../widgets/exercise_tile.dart';
import 'log_exercises_page.dart';

class WorkoutDetailsPage extends StatelessWidget {
  final int workoutId;

  const WorkoutDetailsPage({
    required this.workoutId,
    super.key,
  });

  Future<void> _showAddExerciseDialog(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Exercise'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Exercise Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await dialogContext.read<WorkoutProvider>().addExercise(
                        workoutId,
                        name,
                      );
                }

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRenameExerciseDialog(
    BuildContext context,
    int exerciseId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Exercise'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Exercise Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await dialogContext.read<WorkoutProvider>().renameExercise(
                        exerciseId,
                        name,
                      );
                }

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteExercise(
    BuildContext context,
    int exerciseId,
    String exerciseName,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete Exercise'),
              content: Text(
                'Delete "$exerciseName"? This will also remove any logged sets for it.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !context.mounted) {
      return;
    }

    await context.read<WorkoutProvider>().deleteExercise(exerciseId);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$exerciseName" deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final workout = provider.getWorkoutById(workoutId);

    if (workout == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(
          child: Text('Workout not found.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(workout.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _WorkoutDetailStat(
                        label: 'Exercises',
                        value: '${workout.exercises.length}',
                      ),
                    ),
                    Expanded(
                      child: _WorkoutDetailStat(
                        label: 'Logged Sets',
                        value: workout.exercises
                            .fold<int>(
                              0,
                              (total, exercise) => total + exercise.sets.length,
                            )
                            .toString(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (workout.exercises.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No exercises yet. Add one below.'),
                ),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: workout.exercises.length,
                  onReorderItem: (oldIndex, newIndex) {
                    context.read<WorkoutProvider>().reorderExercises(
                          workoutId,
                          oldIndex,
                          newIndex,
                        );
                  },
                  itemBuilder: (context, index) {
                    final exercise = workout.exercises[index];
                    final exerciseId = exercise.id;
                    return ReorderableDragStartListener(
                      key: ValueKey(exerciseId),
                      index: index,
                      child: ExerciseTile(
                        name: exercise.name,
                        setCount: exercise.sets.length,
                        onEdit: exerciseId == null
                            ? null
                            : () => _showRenameExerciseDialog(
                                  context,
                                  exerciseId,
                                  exercise.name,
                                ),
                        onDelete: exerciseId == null
                            ? null
                            : () => _confirmDeleteExercise(
                                  context,
                                  exerciseId,
                                  exercise.name,
                                ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: workout.exercises.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                LogExercisesPage(workoutId: workoutId),
                          ),
                        );
                      },
                child: const Text('Start Workout'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddExerciseDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Exercise'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutDetailStat extends StatelessWidget {
  final String label;
  final String value;

  const _WorkoutDetailStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(label),
      ],
    );
  }
}
