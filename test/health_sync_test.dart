import 'package:flutter_test/flutter_test.dart';
import 'package:gain_guide/pages/health_page.dart';
import 'package:gain_guide/services/health_sync_page.dart';

void main() {
  test('unavailable data is distinct from a measured zero', () {
    expect(healthDisplay(null, 'steps'), 'Unavailable');
    expect(healthDisplay(0, 'steps'), '0 steps');
  });

  test('offline uploads retry from the last durable checkpoint', () async {
    String? stored;
    var offline = true;
    var commits = 0;
    var queries = <String?>[];
    final daily = [
      {'value': 0},
    ];
    Future<void> sync() => syncHealthPages(
      anchor: stored,
      dirty: false,
      read: (anchor) async {
        queries.add(anchor);
        return {
          'anchor': 'a',
          'samples': anchor == null ? ['new'] : [],
          'removed': [],
          'cumulative': true,
        };
      },
      totals: () async => daily,
      commit: (previous, page, totals, pending) async {
        if (offline) throw StateError('offline');
        expect(previous, stored);
        stored = page['anchor'];
        if (!pending) expect(totals, daily);
        commits++;
      },
    );
    await expectLater(sync(), throwsStateError);
    expect(stored, isNull);
    offline = false;
    await sync();
    await sync();
    expect(queries, [null, null, 'a', 'a']);
    expect(commits, 2);
  });

  test(
    'a restarted import recomputes pending totals after a deletion',
    () async {
      var called = false;
      await syncHealthPages(
        anchor: 'after-delete',
        dirty: true,
        read: (_) async => {
          'anchor': 'final',
          'samples': [],
          'removed': [],
          'cumulative': true,
        },
        totals: () async => [],
        commit: (previous, page, totals, pending) async {
          expect(totals, isEmpty);
          expect(pending, isFalse);
          called = true;
        },
      );
      expect(called, isTrue);
    },
  );
}
