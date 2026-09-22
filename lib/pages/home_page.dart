import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_header.dart';
import '../widgets/metric_card.dart';
import '../widgets/workout_card.dart';
import 'workout_details_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  int _totalSets(List<Workout> history) {
    return history.fold(
      0,
      (total, workout) =>
          total +
          workout.exercises.fold(
            0,
            (exerciseTotal, exercise) => exerciseTotal + exercise.sets.length,
          ),
    );
  }

  int _currentStreak(List<Workout> history) {
    final completedDays = history
        .map((workout) => workout.completedAt)
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();

    if (completedDays.isEmpty) {
      return 0;
    }

    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    var streak = 0;

    while (completedDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  Future<void> _showAddWorkoutDialog(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Workout'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Workout Name',
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
                  await dialogContext.read<WorkoutProvider>().addWorkout(name);
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

  Future<void> _showRenameWorkoutDialog(
    BuildContext context,
    int workoutId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Workout'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Workout Name',
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
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  await dialogContext.read<WorkoutProvider>().renameWorkout(
                        workoutId,
                        newName,
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

  Future<void> _showScheduleDialog(BuildContext context, Workout workout) async {
    final selected = (workout.scheduledWeekdays ?? '')
        .split(',').map(int.tryParse).whereType<int>().toSet();
    var time = TimeOfDay(hour: workout.scheduledHour ?? 18, minute: workout.scheduledMinute ?? 0);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Schedule ${workout.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 6, children: List.generate(7, (i) => FilterChip(
              label: Text(labels[i]), selected: selected.contains(i + 1),
              onSelected: (value) => setState(() => value ? selected.add(i + 1) : selected.remove(i + 1)),
            ))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Workout time'),
              subtitle: Text(time.format(context)),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: time);
                if (picked != null) setState(() => time = picked);
              },
            ),
            const Text('GainGuide will remind you at workout time and again at 9 PM if the workout is still missed.'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: selected.isEmpty ? null : () async {
              await dialogContext.read<WorkoutProvider>().scheduleWorkout(
                workoutId: workout.id!, weekdays: selected.toList(), hour: time.hour, minute: time.minute);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
  Future<void> _confirmDeleteWorkout(
    BuildContext context,
    int workoutId,
    String workoutName,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete Workout'),
              content: Text(
                'Delete "$workoutName"? This will also remove its exercises and logged sets.',
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

    await context.read<WorkoutProvider>().deleteWorkout(workoutId);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$workoutName" deleted')),
    );
  }

  String? _scheduleLabel(String? scheduledWeekdays) {
    if (scheduledWeekdays == null || scheduledWeekdays.trim().isEmpty) return null;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = scheduledWeekdays
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((day) => day >= 1 && day <= 7)
        .map((day) => names[day - 1])
        .toList();
    return days.isEmpty ? null : days.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final workouts = provider.workouts;
    final history = provider.history;
    final currentUser = provider.currentUser;
    final streak = _currentStreak(history);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'signOut') {
                context.read<WorkoutProvider>().signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(currentUser?.displayName ?? 'Signed in'),
                  subtitle: Text(currentUser?.email ?? ''),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'signOut',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Sign Out'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.ink,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.gold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Ready, ${currentUser?.displayName ?? 'athlete'}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            history.isEmpty
                                ? 'Log your first session and start building your training history.'
                                : 'Keep your training consistent and your progress moving.',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.72),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _HeroPill(
                      label: 'Sessions',
                      value: '${history.length}',
                    ),
                    const SizedBox(width: 10),
                    _HeroPill(
                      label: 'Streak',
                      value: '${streak}d',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Workouts',
                  value: '${history.length}',
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'Sets',
                  value: '${_totalSets(history)}',
                  icon: Icons.format_list_numbered,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'Streak',
                  value: '${streak}d',
                  icon: Icons.local_fire_department_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppSectionHeader(
            title: 'Workout Library',
          ),
          if (workouts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No workouts yet. Add one to get started.'),
              ),
            )
          else
            ReorderableListView.builder(
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                child: child,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: workouts.length,
              onReorderItem: (oldIndex, newIndex) {
                context.read<WorkoutProvider>().reorderWorkouts(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
              final workout = workouts[index];
              final workoutId = workout.id;
              final scheduleLabel = _scheduleLabel(workout.scheduledWeekdays);

              if (workoutId == null) {
                return SizedBox.shrink(key: ValueKey('missing-$index'));
              }

              return WorkoutCard(
                key: ValueKey(workoutId),
                dragIndex: index,
                scheduleLabel: scheduleLabel,
                title: workout.name,
                exerciseCount: workout.exercises.length,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutDetailsPage(workoutId: workoutId),
                    ),
                  );
                },
                onSchedule: () => _showScheduleDialog(context, workout),
                onRename: () => _showRenameWorkoutDialog(
                  context,
                  workoutId,
                  workout.name,
                ),
                onDelete: () => _confirmDeleteWorkout(
                  context,
                  workoutId,
                  workout.name,
                ),
              );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWorkoutDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Workout'),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final String value;

  const _HeroPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    height: 1,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
