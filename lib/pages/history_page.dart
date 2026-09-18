import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/workout_provider.dart';
import '../widgets/metric_card.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  int _totalSets(Workout workout) {
    return workout.exercises.fold(
      0,
      (total, exercise) => total + exercise.sets.length,
    );
  }

  double _totalVolume(Workout workout) {
    double total = 0;

    for (final exercise in workout.exercises) {
      for (final set in exercise.sets) {
        total += set.weight * set.reps;
      }
    }

    return total;
  }

  int _totalExercises(List<Workout> history) {
    return history.fold(
      0,
      (total, workout) => total + workout.exercises.length,
    );
  }

  int _totalHistorySets(List<Workout> history) {
    return history.fold(
      0,
      (total, workout) => total + _totalSets(workout),
    );
  }

  double _totalHistoryVolume(List<Workout> history) {
    return history.fold(
      0,
      (total, workout) => total + _totalVolume(workout),
    );
  }

  Future<void> _refresh(BuildContext context) async {
    await context.read<WorkoutProvider>().loadHistory();
  }

  Future<void> _deleteWorkout(BuildContext context, Workout workout) async {
    if (workout.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text('Delete "${workout.name}" from your history? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    ) ?? false;
    if (!confirmed || !context.mounted) return;
    await context.read<WorkoutProvider>().deleteHistoryWorkout(workout.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout deleted from history')));
  }

  Future<void> _exportRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
    );

    if (range == null || !context.mounted) {
      return;
    }

    final exportText = await context.read<WorkoutProvider>().buildWorkoutExport(
          start: range.start,
          end: range.end,
        );
    await Clipboard.setData(ClipboardData(text: exportText));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout export copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<WorkoutProvider>().history;
    final formatter = DateFormat('MMM d, yyyy - h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Export workouts',
            onPressed: () => _exportRange(context),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: history.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.history, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No completed workouts yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Complete a workout and it will appear here with its exercises and logged sets.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _HistoryOverview(
                    workoutCount: history.length,
                    exerciseCount: _totalExercises(history),
                    setCount: _totalHistorySets(history),
                    volume: _totalHistoryVolume(history),
                  ),
                  const SizedBox(height: 16),
                  _HistoryTrendChart(history: history),
                  const SizedBox(height: 16),
                  ...history.map((workout) {
                    final dateText = workout.completedAt != null
                        ? formatter.format(workout.completedAt!)
                        : 'Unknown Date';
                    final totalSets = _totalSets(workout);
                    final totalVolume = _totalVolume(workout);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: const Icon(Icons.fitness_center),
                        title: Row(
                          children: [
                            Expanded(child: Text(workout.name)),
                            IconButton(
                              tooltip: 'Delete from history',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteWorkout(context, workout),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '$dateText\n${workout.exercises.length} exercise(s) - '
                          '$totalSets set(s) - ${totalVolume.toStringAsFixed(0)} lbs total volume',
                        ),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: workout.exercises.isEmpty
                            ? const [
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text('No exercises were logged.'),
                                ),
                              ]
                            : workout.exercises.map((exercise) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercise.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (exercise.sets.isEmpty)
                                        const Text('No sets logged')
                                      else
                                        ...exercise.sets
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final index = entry.key;
                                          final setEntry = entry.value;

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 4),
                                            child: Text(
                                              'Set ${index + 1}: ${setEntry.weight.toStringAsFixed(1)} lbs x ${setEntry.reps} reps',
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                );
                              }).toList(),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}

class _HistoryOverview extends StatelessWidget {
  final int workoutCount;
  final int exerciseCount;
  final int setCount;
  final double volume;

  const _HistoryOverview({
    required this.workoutCount,
    required this.exerciseCount,
    required this.setCount,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Completed',
                value: '$workoutCount',
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Exercises',
                value: '$exerciseCount',
                icon: Icons.list_alt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Sets',
                value: '$setCount',
                icon: Icons.format_list_numbered,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Volume',
                value: volume.toStringAsFixed(0),
                icon: Icons.trending_up,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HistoryTrendChart extends StatelessWidget {
  final List<Workout> history;

  const _HistoryTrendChart({required this.history});

  double _volume(Workout workout) {
    var total = 0.0;
    for (final exercise in workout.exercises) {
      for (final set in exercise.sets) {
        total += set.weight * set.reps;
      }
    }
    return total;
  }

  List<_ChartPoint> _points() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 27));
    final buckets = <DateTime, double>{};

    for (var i = 0; i < 28; i++) {
      final day = start.add(Duration(days: i));
      buckets[day] = 0;
    }

    for (final workout in history) {
      final completedAt = workout.completedAt;
      if (completedAt == null) {
        continue;
      }

      final day = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );

      if (buckets.containsKey(day)) {
        buckets[day] = buckets[day]! + _volume(workout);
      }
    }

    return buckets.entries
        .map((entry) => _ChartPoint(entry.key, entry.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final points = _points();
    final peak = points.fold<double>(
      0,
      (best, point) => point.value > best ? point.value : best,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '28-Day Volume Trend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              peak == 0
                  ? 'Complete workouts to see your training load build here.'
                  : 'Peak day: ${peak.toStringAsFixed(0)} lbs',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                painter: _VolumeTrendPainter(
                  points: points,
                  color: Theme.of(context).colorScheme.primary,
                  mutedColor: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartPoint {
  final DateTime date;
  final double value;

  const _ChartPoint(this.date, this.value);
}

class _VolumeTrendPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final Color color;
  final Color mutedColor;

  const _VolumeTrendPainter({
    required this.points,
    required this.color,
    required this.mutedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = mutedColor.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    final barPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final labelPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (var i = 0; i < 4; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maxValue = points.fold<double>(
      0,
      (best, point) => point.value > best ? point.value : best,
    );
    final safeMax = maxValue == 0 ? 1 : maxValue;
    const gap = 3.0;
    final barWidth = (size.width - (gap * (points.length - 1))) / points.length;

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final normalized = point.value / safeMax;
      final barHeight = normalized == 0 ? 3.0 : (size.height - 24) * normalized;
      final left = i * (barWidth + gap);
      final top = size.height - 24 - barHeight;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          const Radius.circular(4),
        ),
        barPaint..color = normalized == 0 ? mutedColor.withValues(alpha: 0.45) : color,
      );
    }

    final labels = [
      points.first.date,
      points[points.length ~/ 2].date,
      points.last.date,
    ];
    final labelPositions = [0.0, size.width / 2, size.width];

    for (var i = 0; i < labels.length; i++) {
      labelPainter.text = TextSpan(
        text: DateFormat('MMM d').format(labels[i]),
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      labelPainter.layout();
      final dx = (labelPositions[i] - labelPainter.width / 2)
          .clamp(0.0, size.width - labelPainter.width);
      labelPainter.paint(canvas, Offset(dx, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _VolumeTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.mutedColor != mutedColor;
  }
}
