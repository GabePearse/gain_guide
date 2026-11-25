import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/apple_health_service.dart';

class HealthSettings extends StatefulWidget {
  const HealthSettings({super.key});
  @override
  State<HealthSettings> createState() => _HealthSettingsState();
}

class _HealthSettingsState extends State<HealthSettings> {
  final service = AppleHealthService.instance;
  final selected = <String>{};
  final days = TextEditingController(text: '90');
  final groups = const {
    'activity': 'Steps, active and resting energy, distance, exercise minutes',
    'body': 'Weight, body fat, lean body mass, BMI',
    'nutrition': 'Calories, protein, carbohydrates, fat, fibre, water',
    'recovery':
        'Sleep duration and stages, resting heart rate, HRV, respiratory rate',
  };
  HealthRow? cfg;
  List<HealthRow> sources = [];
  bool available = false, working = true, bound = false;
  String? message;

  @override
  void initState() {
    super.initState();
    run(load);
  }

  @override
  void dispose() {
    days.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      working = true;
      message = null;
    });
    try {
      await action();
    } catch (_) {
      message = 'Could not complete the request. Check your connection and try again.';
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> load() async {
    final native =
        service.ios &&
        await AppleHealthService.channel.invokeMethod<bool>('available') ==
            true;
    final grant = native
        ? await AppleHealthService.channel.invokeMapMethod<String, dynamic>(
            'grant',
          )
        : null;
    if (!mounted) return;
    available = native;
    bound = grant != null && grant['owner'] == service.owner;
    final config = await service.configuration();
    if (!mounted) return;
    cfg = config;
    bound =
        config != null &&
        grant?['revision'] == config['revision'] &&
        grant?['owner'] == service.owner;
    available = native;
    selected
      ..clear()
      ..addAll(List<String>.from(cfg?['categories'] ?? []));
    days.text = (cfg?['lookback'] ?? 90).toString();
    final id = service.owner;
    if (id != null) {
      final observed = await service.db
          .from('health_sources')
          .select('metric,source')
          .eq('user_id', id)
          .order('source')
          .order('metric');
      if (mounted && id == service.owner) sources = observed;
    }
  }

  Future<void> erase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete synchronized health data?'),
        content: const Text(
          'This removes all imported Apple Health data from your GainGuide account and disconnects sync. Your workouts and the originals in Apple Health are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete health data'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await run(() async {
        await service.disconnect(true);
        await load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final locked = working || service.syncing;
      final stamp =
          service.lastSync ??
          DateTime.tryParse(cfg?['last_success'] ?? '')?.toLocal();
      final count = int.tryParse(days.text);
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Apple Health',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text(
              'GainGuide can upload the categories you select to your private Supabase account data to compare health trends with your workouts. Each reading includes its time, unit, source app and HealthKit identifier. We use this data for your fitness analysis and never for advertising.',
            ),
            if (!available && !working)
              const ListTile(
                leading: Icon(Icons.phone_iphone),
                title: Text('Connect using the GainGuide iPhone app'),
              ),
            for (final item in groups.entries)
              CheckboxListTile(
                value: selected.contains(item.key),
                onChanged: !available || locked
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          selected.add(item.key);
                        } else {
                          selected.remove(item.key);
                        }
                      }),
                title: Text(toBeginningOfSentenceCase(item.key)),
                subtitle: Text(item.value),
              ),
            TextField(
              controller: days,
              enabled: available && !locked,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Historical import (days)',
                helperText: '1 to 3,650 days',
              ),
            ),
            if (available)
              FilledButton(
                onPressed:
                    locked ||
                        selected.isEmpty ||
                        count == null ||
                        count < 1 ||
                        count > 3650
                    ? null
                    : () => run(() async {
                        await service.connect(selected.toList(), count);
                        await load();
                      }),
                child: Text(
                  bound
                      ? 'Save choices and consent to upload'
                      : 'Connect Apple Health and consent to upload',
                ),
              ),
            ListTile(
              title: const Text('Last successful sync'),
              subtitle: Text(
                stamp == null
                    ? 'Never'
                    : DateFormat.yMMMd().add_jm().format(stamp),
              ),
            ),
            Text(
              message ??
                  service.error ??
                  (working
                      ? 'Loading…'
                      : service.syncing
                      ? 'Synchronizing…'
                      : bound
                      ? 'Connected on this iPhone'
                      : cfg == null
                      ? 'Disconnected'
                      : 'Connected on another installation'),
            ),
            ExpansionTile(
              title: const Text('Observed data sources'),
              children: sources.isEmpty
                  ? [
                      const ListTile(
                        title: Text('No synchronized readings available'),
                      ),
                    ]
                  : [
                      for (final row in sources)
                        ListTile(
                          title: Text(
                            healthMetrics[row['metric']] ?? row['metric'],
                          ),
                          subtitle: Text(row['source']),
                        ),
                    ],
            ),
            if (bound)
              OutlinedButton(
                onPressed: locked ? null : () => run(service.sync),
                child: const Text('Sync now'),
              ),
            if (available)
              const ListTile(
                title: Text('Manage permissions'),
                subtitle: Text(
                  'In Health, open your profile → Apps → GainGuide to review or revoke individual read permissions.',
                ),
              ),
            if (cfg != null || bound)
              TextButton(
                onPressed: working
                    ? null
                    : () => run(() async {
                        await service.disconnect(false);
                        await load();
                      }),
                child: const Text('Disconnect Apple Health'),
              ),
            TextButton(
              onPressed: working ? null : erase,
              child: const Text('Delete previously synchronized health data'),
            ),
          ],
        ),
      );
    },
  );
}

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});
  @override
  State<HealthPage> createState() => _HealthPageState();
}

String healthDisplay(num? value, String unit) => value == null
    ? 'Unavailable'
    : '${NumberFormat('0.##').format(value)} $unit';

class _HealthPageState extends State<HealthPage> {
  String period = 'Day';
  DateTime date = DateTime.now();
  late Future<List<HealthRow>> data;
  final format = DateFormat('yyyy-MM-dd');

  DateTime boundary(int offset) => switch (period) {
    'Week' => DateTime(
      date.year,
      date.month,
      date.day - date.weekday + 1 + 7 * offset,
    ),
    'Month' => DateTime(date.year, date.month + offset),
    _ => DateTime(date.year, date.month, date.day + offset),
  };
  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    final service = AppleHealthService.instance;
    data = service.range(
      'health_daily',
      'day',
      format.format(boundary(0)),
      format.format(boundary(1)),
      ['day', 'metric'],
      user: service.owner!,
    );
  }

  void change(VoidCallback update) => setState(() {
    update();
    refresh();
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Health'),
      actions: [
        IconButton(
          tooltip: 'Apple Health settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HealthSettings()),
            );
            if (mounted) change(() {});
          },
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<String>(
          segments: [
            for (final p in ['Day', 'Week', 'Month'])
              ButtonSegment(value: p, label: Text(p)),
          ],
          selected: {period},
          onSelectionChanged: (v) => change(() => period = v.first),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Previous period',
              onPressed: () => change(() => date = boundary(-1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(DateFormat.yMMMd().format(boundary(0))),
            IconButton(
              tooltip: 'Next period',
              onPressed: boundary(1).isAfter(DateTime.now())
                  ? null
                  : () => change(() => date = boundary(1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        FutureBuilder<List<HealthRow>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return TextButton(
                onPressed: () => change(() {}),
                child: const Text('Could not load health data. Retry'),
              );
            }
            final rows = snapshot.data ?? [];
            return Column(
              children: [
                for (final item in healthMetrics.entries)
                  Builder(
                    builder: (context) {
                      final series = rows
                          .where((r) => r['metric'] == item.key)
                          .toList();
                      final unit = series.isEmpty
                          ? ''
                          : series.first['unit'] as String;
                      final avg = series.isEmpty
                          ? null
                          : series.fold<double>(
                                  0,
                                  (n, r) => n + (r['value'] as num),
                                ) /
                                series.length;
                      return Card(
                        child: ExpansionTile(
                          title: Text(item.value),
                          trailing: Text(healthDisplay(avg, unit)),
                          subtitle: period == 'Day' || series.isEmpty
                              ? null
                              : Text(
                                  'Daily average · ${series.length} observed days',
                                ),
                          children: [
                            for (final r in series)
                              ListTile(
                                title: Text(r['day']),
                                trailing: Text(healthDisplay(r['value'], unit)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
