import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/workout_provider.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  static const String _allExercises = 'All Exercises';

  String _selectedRange = '30 Days';
  String _selectedExercise = _allExercises;

  final List<String> _ranges = const [
    '7 Days',
    '30 Days',
    'All Time',
  ];

  List<Workout> _filterByRange(List<Workout> history) {
    if (_selectedRange == 'All Time') {
      return history;
    }

    final now = DateTime.now();
    final cutoff = _selectedRange == '7 Days'
        ? now.subtract(const Duration(days: 7))
        : now.subtract(const Duration(days: 30));

    return history.where((workout) {
      final completedAt = workout.completedAt;
      return completedAt != null && !completedAt.isBefore(cutoff);
    }).toList();
  }

  List<String> _exerciseOptions(List<Workout> history) {
    final names = <String>{};

    for (final workout in history) {
      for (final exercise in workout.exercises) {
        names.add(exercise.name);
      }
    }

    final sorted = names.toList()..sort((a, b) => a.compareTo(b));
    return [_allExercises, ...sorted];
  }

  List<_ProgressEntry> _entriesFromHistory(List<Workout> history) {
    final entries = <_ProgressEntry>[];

    for (final workout in history) {
      final completedAt = workout.completedAt;
      if (completedAt == null) {
        continue;
      }

      for (final exercise in workout.exercises) {
        if (_selectedExercise != _allExercises &&
            exercise.name != _selectedExercise) {
          continue;
        }

        for (final set in exercise.sets) {
          entries.add(
            _ProgressEntry(
              date: completedAt,
              workoutName: workout.name,
              exerciseName: exercise.name,
              reps: set.reps,
              weight: set.weight,
            ),
          );
        }
      }
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  int _sessionCount(List<Workout> history) {
    if (_selectedExercise == _allExercises) {
      return history.length;
    }

    int count = 0;

    for (final workout in history) {
      final hasSelectedExercise = workout.exercises.any(
        (exercise) =>
            exercise.name == _selectedExercise && exercise.sets.isNotEmpty,
      );

      if (hasSelectedExercise) {
        count++;
      }
    }

    return count;
  }

  double _averageWeight(List<_ProgressEntry> entries) {
    if (entries.isEmpty) {
      return 0;
    }

    final totalWeight = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.weight,
    );

    return totalWeight / entries.length;
  }

  double _totalVolume(List<_ProgressEntry> entries) {
    return entries.fold<double>(
      0,
      (sum, entry) => sum + entry.volume,
    );
  }

  _ProgressEntry? _personalBest(List<_ProgressEntry> entries) {
    if (entries.isEmpty) {
      return null;
    }

    _ProgressEntry best = entries.first;

    for (final entry in entries.skip(1)) {
      if (entry.weight > best.weight) {
        best = entry;
      }
    }

    return best;
  }

  Future<void> _refresh(BuildContext context) async {
    await context.read<WorkoutProvider>().loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<WorkoutProvider>().history;
    final rangeFilteredHistory = _filterByRange(history);
    final exerciseOptions = _exerciseOptions(history);

    final selectedExercise = exerciseOptions.contains(_selectedExercise)
        ? _selectedExercise
        : _allExercises;

    final entries = _entriesFromHistory(rangeFilteredHistory);
    final sessionCount = _sessionCount(rangeFilteredHistory);
    final totalSets = entries.length;
    final averageWeight = _averageWeight(entries);
    final totalVolume = _totalVolume(entries);
    final personalBest = _personalBest(entries);
    final formatter = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: history.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.bar_chart, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No progress data yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Complete workouts with logged sets and your progress summaries will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRange,
                    decoration: const InputDecoration(
                      labelText: 'Time Range',
                      border: OutlineInputBorder(),
                    ),
                    items: _ranges
                        .map(
                          (range) => DropdownMenuItem(
                            value: range,
                            child: Text(range),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedRange = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedExercise,
                    decoration: const InputDecoration(
                      labelText: 'Exercise',
                      border: OutlineInputBorder(),
                    ),
                    items: exerciseOptions
                        .map(
                          (exercise) => DropdownMenuItem(
                            value: exercise,
                            child: Text(exercise),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedExercise = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ProgressCard(
                          label: 'Sessions',
                          value: '$sessionCount',
                          icon: Icons.calendar_today_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProgressCard(
                          label: 'Sets',
                          value: '$totalSets',
                          icon: Icons.format_list_numbered,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ProgressCard(
                          label: 'Avg Weight',
                          value: '${averageWeight.toStringAsFixed(1)}lbs',
                          icon: Icons.scale_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProgressCard(
                          label: 'Volume',
                          value: '${totalVolume.toStringAsFixed(0)}lbs',
                          icon: Icons.insights_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ProgressTrendChart(entries: entries),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: personalBest == null
                          ? const Text(
                              'No sets found for the selected filters.',
                              textAlign: TextAlign.center,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Personal Best',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${personalBest.weight.toStringAsFixed(1)} lbs x ${personalBest.reps} reps',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  personalBest.exerciseName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(formatter.format(personalBest.date)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: entries.isEmpty
                          ? const Text(
                              'No recent sets found for the selected filters.',
                              textAlign: TextAlign.center,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Recent Sets',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...entries.take(10).map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.fitness_center,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${entry.exerciseName}: ${entry.weight.toStringAsFixed(1)} lbs x ${entry.reps} reps',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(entry.workoutName),
                                              Text(
                                                  formatter.format(entry.date)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProgressCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ProgressEntry {
  final DateTime date;
  final String workoutName;
  final String exerciseName;
  final int reps;
  final double weight;

  const _ProgressEntry({
    required this.date,
    required this.workoutName,
    required this.exerciseName,
    required this.reps,
    required this.weight,
  });

  double get volume => reps * weight;
}

class _ProgressTrendChart extends StatelessWidget {
  final List<_ProgressEntry> entries;

  const _ProgressTrendChart({required this.entries});

  List<_ProgressChartPoint> _points() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 27));
    final buckets = <DateTime, double>{};

    for (var i = 0; i < 28; i++) {
      buckets[start.add(Duration(days: i))] = 0;
    }

    for (final entry in entries) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (buckets.containsKey(day) && entry.weight > buckets[day]!) {
        buckets[day] = entry.weight;
      }
    }

    return buckets.entries
        .map((entry) => _ProgressChartPoint(entry.key, entry.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final points = _points();
    final best = points.fold<double>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Strength Trend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              best == 0
                  ? 'Log sets to see your heaviest work trend here.'
                  : 'Best point in range: ${best.toStringAsFixed(1)} lbs',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: CustomPaint(
                painter: _StrengthTrendPainter(
                  points: points,
                  color: Theme.of(context).colorScheme.secondary,
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

class _ProgressChartPoint {
  final DateTime date;
  final double value;

  const _ProgressChartPoint(this.date, this.value);
}

class _StrengthTrendPainter extends CustomPainter {
  final List<_ProgressChartPoint> points;
  final Color color;
  final Color mutedColor;

  const _StrengthTrendPainter({
    required this.points,
    required this.color,
    required this.mutedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = mutedColor.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 4; i++) {
      final y = (size.height - 20) * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maxValue = points.fold<double>(
      0,
      (best, point) => point.value > best ? point.value : best,
    );
    if (maxValue == 0) {
      return;
    }

    final path = Path();
    var hasStarted = false;

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      if (point.value == 0) {
        continue;
      }

      final x = points.length == 1 ? 0.0 : (size.width / (points.length - 1)) * i;
      final y = (size.height - 24) - ((point.value / maxValue) * (size.height - 28));
      final offset = Offset(x, y);

      if (!hasStarted) {
        path.moveTo(offset.dx, offset.dy);
        hasStarted = true;
      } else {
        path.lineTo(offset.dx, offset.dy);
      }

      canvas.drawCircle(offset, 4, dotPaint);
    }

    if (hasStarted) {
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrengthTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.mutedColor != mutedColor;
  }
}
