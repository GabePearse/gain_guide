import 'dart:async';

import 'health_sync_page.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef HealthRow = Map<String, dynamic>;

const healthMetrics = {
  'steps': 'Daily steps',
  'active_energy': 'Active energy',
  'resting_energy': 'Resting energy',
  'distance': 'Walking and running distance',
  'exercise': 'Exercise minutes',
  'weight': 'Weight',
  'body_fat': 'Body fat',
  'lean_mass': 'Lean body mass',
  'bmi': 'BMI',
  'calories': 'Calories consumed',
  'protein': 'Protein',
  'carbs': 'Carbohydrates',
  'fat': 'Fat',
  'fibre': 'Fibre',
  'water': 'Water intake',
  'sleep': 'Sleep duration',
  'resting_hr': 'Resting heart rate',
  'hrv': 'Heart rate variability (SDNN)',
  'respiration': 'Respiratory rate',
};

class AppleHealthService extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = AppleHealthService();
  static const channel = MethodChannel('gain_guide/health');
  SupabaseClient get db => Supabase.instance.client;
  bool get ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  String? get owner => db.auth.currentUser?.id;
  bool syncing = false;
  String? error;
  DateTime? lastSync;
  Future<void>? _flight;
  Future<void>? _delivery;
  bool _observerPending = false;
  Timer? _retry;
  int _failures = 0;
  int _generation = 0;

  Future<void> initialize() async {
    if (!ios) return;
    WidgetsBinding.instance.addObserver(this);
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') {
        _observerPending = true;
        await (_delivery ??= _drainObservers().whenComplete(
          () => _delivery = null,
        ));
      }
    });
    String? activeOwner = owner;
    db.auth.onAuthStateChange.listen((event) {
      if (owner != activeOwner) {
        activeOwner = owner;
        _generation++;
        error = null;
        lastSync = null;
        _retry?.cancel();
        notifyListeners();
        final previous = _flight;
        if (previous != null) {
          unawaited(previous.then((_) => sync()));
        } else {
          unawaited(sync());
        }
      }
    });
    await channel.invokeMethod<void>('ready');
    unawaited(sync());
  }

  // An observer can arrive after its metric was read by an active sync.
  // Coalesce notifications and perform a subsequent pass before replying.
  Future<void> _drainObservers() async {
    await _flight;
    while (_observerPending) {
      _observerPending = false;
      await sync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(sync());
  }

  Future<HealthRow?> configuration() async {
    final id = owner;
    if (id == null) return null;
    return db
        .from('health_connection')
        .select()
        .eq('user_id', id)
        .maybeSingle();
  }

  Future<void> connect(List<String> categories, int days) async {
    final id = owner!;
    await channel.invokeMethod<void>('authorize', {'categories': categories});
    final zone = await channel.invokeMethod<String>('zone');
    if (id != owner) throw StateError('Account changed');
    _generation++;
    final revision = await db.rpc(
      'health_configure',
      params: {
        'owner': id,
        'selected': categories,
        'days': days,
        'timezone_name': zone,
      },
    );
    if (id != owner) throw StateError('Account changed');
    await channel.invokeMethod<void>('bind', {
      'owner': id,
      'revision': revision,
      'categories': categories,
    });
    await _flight;
    unawaited(sync());
  }

  Future<void> disconnect(bool erase) async {
    final id = owner!;
    _generation++;
    _retry?.cancel();
    if (ios) await channel.invokeMethod<void>('unbind', {'owner': id});
    await db.rpc('health_disconnect', params: {'owner': id, 'erase': erase});
    lastSync = null;
    error = null;
    notifyListeners();
  }

  Future<void> sync() {
    if (!ios || owner == null) return Future.value();
    return _flight ??= _run(
      owner!,
      _generation,
    ).whenComplete(() => _flight = null);
  }

  Future<void> _run(String id, int generation) async {
    void guard() {
      if (id != owner || generation != _generation) {
        throw StateError('Account changed');
      }
    }

    try {
      final grant = await channel.invokeMapMethod<String, dynamic>('grant');
      if (grant == null || grant['owner'] != id) return;
      guard();
      syncing = true;
      error = null;
      notifyListeners();
      final cfg = await configuration();
      guard();
      if (cfg == null || cfg['revision'] != grant['revision']) return;
      final rows = await db
          .from('health_checkpoint')
          .select()
          .eq('user_id', id);
      final checkpoints = {for (final row in rows) row['metric']: row};
      final metrics = await channel.invokeListMethod<String>('metrics') ?? [];
      for (final kind in metrics) {
        final anchor = checkpoints[kind]?['anchor'] as String?;
        final dirty = checkpoints[kind]?['dirty'] == true;
        final query = {
          'owner': id,
          'revision': cfg['revision'],
          'metric': kind,
          'zone': cfg['zone'],
          'since': DateTime.parse(cfg['since']).millisecondsSinceEpoch / 1000,
        };
        await syncHealthPages(
          anchor: anchor,
          dirty: dirty,
          read: (anchor) async {
            guard();
            return (await channel.invokeMapMethod<String, dynamic>('page', {
              ...query,
              'anchor': anchor,
            }))!;
          },
          totals: () => channel.invokeListMethod<dynamic>('totals', query),
          commit: (previous, page, totals, pending) async {
            guard();
            await db.rpc(
              'health_apply',
              params: {
                'owner': id,
                'grant_id': cfg['revision'],
                'kind': kind,
                'previous': previous,
                'next_anchor': page['anchor'],
                'samples': page['samples'],
                'removed': page['removed'],
                'totals': totals,
                'pending': pending,
              },
            );
          },
        );
      }
      guard();
      final stamp = await db.rpc(
        'health_finish',
        params: {'owner': id, 'grant_id': cfg['revision']},
      );
      guard();
      lastSync = DateTime.parse(stamp as String).toLocal();
      _failures = 0;
      _retry?.cancel();
    } catch (_) {
      if (id == owner && generation == _generation) {
        error = 'Sync paused. Check your connection and unlock your iPhone. GainGuide will retry.';
        _retry?.cancel();
        _retry = Timer(Duration(seconds: 5 << _failures.clamp(0, 6)), sync);
        _failures++;
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<List<HealthRow>> range(
    String table,
    String column,
    String start,
    String end,
    List<String> order, {
    required String user,
  }) async {
    final result = <HealthRow>[];
    const size = 500;
    for (var offset = 0; ; offset += size) {
      if (user != owner) throw StateError('Account changed');
      final base = db
          .from(table)
          .select()
          .eq('user_id', user)
          .gte(column, start)
          .lt(column, end);
      var request = base.order(order.first);
      for (final key in order.skip(1)) {
        request = request.order(key);
      }
      final page = await request.range(offset, offset + size - 1);
      result.addAll(page);
      if (page.length < size) break;
    }
    if (user != owner) throw StateError('Account changed');
    return result;
  }

  Future<String> export(DateTime start, DateTime end, String user) async {
    final day = DateFormat('yyyy-MM-dd');
    final until = DateTime(end.year, end.month, end.day + 1);
    final daily = await range(
      'health_daily',
      'day',
      day.format(start),
      day.format(until),
      ['day', 'metric'],
      user: user,
    );
    final samples = await range(
      'health_export_samples',
      'local_day',
      day.format(start),
      day.format(until),
      ['started', 'id'],
      user: user,
    );
    final output = StringBuffer();
    for (final section in {
      'Daily health metrics': daily,
      'Apple Health samples': samples,
    }.entries) {
      output.writeln(section.key);
      if (section.value.isEmpty) output.writeln('Unavailable');
      for (final row in section.value) {
        output.writeln(jsonEncode(Map.of(row)..remove('user_id')));
      }
    }
    return output.toString();
  }
}
