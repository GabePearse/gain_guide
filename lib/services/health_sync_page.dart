// A failed read, upload, or daily-total refresh leaves the last acknowledged
// cursor usable. HealthKit itself retains the offline journal.
Future<void> syncHealthPages({
  required String? anchor,
  required bool dirty,
  required Future<Map<String, dynamic>> Function(String?) read,
  required Future<List<dynamic>?> Function() totals,
  required Future<void> Function(
    String?,
    Map<String, dynamic>,
    List<dynamic>?,
    bool,
  )
  commit,
}) async {
  while (true) {
    final page = await read(anchor);
    final changed =
        (page['samples'] as List).isNotEmpty ||
        (page['removed'] as List).isNotEmpty;
    dirty = dirty || changed || anchor == null;
    final daily = !changed && dirty && page['cumulative'] == true
        ? await totals()
        : null;
    if (changed || dirty || page['anchor'] != anchor) {
      await commit(anchor, page, daily, changed);
    }
    anchor = page['anchor'] as String;
    if (!changed) return;
  }
}
