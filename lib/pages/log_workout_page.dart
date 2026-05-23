import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/workout_provider.dart';
import '../widgets/rest_timer_card.dart';

class LogWorkoutPage extends StatefulWidget {
  final int workoutId;
  final int exerciseId;

  const LogWorkoutPage({
    required this.workoutId,
    required this.exerciseId,
    super.key,
  });

  @override
  State<LogWorkoutPage> createState() => _LogWorkoutPageState();
}

class _LogWorkoutPageState extends State<LogWorkoutPage> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _repsFocusNode = FocusNode();

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _addSet() async {
    final weightText = _weightController.text.trim();
    final repsText = _repsController.text.trim();

    final weight = double.tryParse(weightText);
    final reps = int.tryParse(repsText);

    if (weightText.isEmpty || repsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both weight and reps')),
      );
      return;
    }

    if (weight == null || weight < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight')),
      );
      return;
    }

    if (reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid reps greater than 0')),
      );
      return;
    }

    await context.read<WorkoutProvider>().logExerciseSet(
          exerciseId: widget.exerciseId,
          reps: reps,
          weight: weight,
        );

    _weightController.clear();
    _repsController.clear();

    if (!mounted) return;
    _weightFocusNode.requestFocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Set added')),
    );
  }

  Future<void> _deleteSet(int setEntryId) async {
    await context.read<WorkoutProvider>().deleteSetEntry(setEntryId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Set removed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final workout = provider.getWorkoutById(widget.workoutId);
    final exercise = provider.getExerciseById(widget.exerciseId);

    if (workout == null || exercise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Log Exercise')),
        body: const Center(
          child: Text('Exercise not found.'),
        ),
      );
    }

    final totalSets = exercise.sets.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
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
                      child: _ExerciseStat(
                        label: 'Workout',
                        value: workout.name,
                      ),
                    ),
                    Expanded(
                      child: _ExerciseStat(
                        label: 'Total Sets',
                        value: '$totalSets',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const RestTimerCard(),
            const SizedBox(height: 12),
            Expanded(
              child: exercise.sets.isEmpty
                  ? const Center(
                      child:
                          Text('No sets logged yet. Add your first set below.'),
                    )
                  : ListView.builder(
                      itemCount: exercise.sets.length,
                      itemBuilder: (context, index) {
                        final set = exercise.sets[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text('Set ${index + 1}'),
                            subtitle: Text(
                              '${set.weight.toStringAsFixed(1)} lbs x ${set.reps} reps',
                            ),
                            trailing: set.id == null
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete set',
                                    onPressed: () => _deleteSet(set.id!),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weightController,
              focusNode: _weightFocusNode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _repsFocusNode.requestFocus(),
              decoration: const InputDecoration(
                labelText: 'Weight (lbs)',
                hintText: 'Example: 135',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _repsController,
              focusNode: _repsFocusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addSet(),
              decoration: const InputDecoration(
                labelText: 'Reps',
                hintText: 'Example: 8',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addSet,
                icon: const Icon(Icons.add),
                label: const Text('Add Set'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Exercises'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseStat extends StatelessWidget {
  final String label;
  final String value;

  const _ExerciseStat({
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
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}
