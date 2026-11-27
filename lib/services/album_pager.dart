/// Reusable bounded, lazy album pagination independent of photo_manager
/// so boundaries and >800 media items can be tested without device access.
typedef AlbumRangeReader<T> = Future<List<T>> Function(int start, int end);

class AlbumPager<T> {
  AlbumPager({required this.readRange, this.pageSize = 64})
      : assert(pageSize > 0);

  final AlbumRangeReader<T> readRange;
  final int pageSize;

  final Map<int, Future<List<T>>> _pages = {};
  final Map<int, T> _seed = {};

  void prime(int index, T item) {
    if (index >= 0) _seed[index] = item;
  }

  Future<T?> at(int index) async {
    if (index < 0) return null;
    if (_seed.containsKey(index)) return _seed[index];
    final page = index ~/ pageSize;
    try {
      final items = await _pages.putIfAbsent(page, () =>
          readRange(page * pageSize, (page + 1) * pageSize));
      final offset = index % pageSize;
      return offset < items.length ? items[offset] : null;
    } catch (_) {
      // Retry transient MediaStore failures on the next request.
      _pages.remove(page);
      rethrow;
    }
  }

  /// Warm one next album page when the viewer is within two items of a
  /// boundary. This reuses the same cached Future as foreground reads and
  /// never scans beyond [totalCount], requests full-size photos, or writes.
  ///
  /// The caller can ignore a transient warm-up error: [at] evicts the
  /// failed Future so the foreground page may retry normally.
  Future<void> prefetchNext(int index, {required int totalCount}) async {
    if (index < 0 || totalCount <= 0 || index >= totalCount) return;
    if (index % pageSize < pageSize - 2) return;
    final nextStart = ((index ~/ pageSize) + 1) * pageSize;
    if (nextStart >= totalCount) return;
    // Do not request MediaStore entries beyond the selected album count.
    // Share this same bounded Future with the next foreground at() call.
    final boundedEnd = nextStart + pageSize < totalCount
        ? nextStart + pageSize : totalCount;
    final page = nextStart ~/ pageSize;
    try {
      await _pages.putIfAbsent(page, () => readRange(nextStart, boundedEnd));
    } catch (_) {
      _pages.remove(page);
      rethrow;
    }
  }

  /// Keep only neighboring pages. Does not cancel already pending platform
  /// operations; it bounds retained page futures and media entities.
  void retainNear(int index) {
    final active = index ~/ pageSize;
    _pages.removeWhere((page, _) => (page - active).abs() > 2);
    _seed.removeWhere((position, _) =>
        ((position ~/ pageSize) - active).abs() > 2);
  }

  void clear() {
    _pages.clear();
    _seed.clear();
  }
}
