/// A testable forward-only MediaStore paging primitive. Unlike a fixed
/// bootstrap limit it visits every accessible page, including after index 800.
typedef CatalogPageReader<T> = Future<List<T>> Function(int page, int size);

abstract final class CatalogPager {
  static Future<void> scan<T>({
    required CatalogPageReader<T> read,
    required void Function(int index, T item) onItem,
    void Function(int scanned)? onPage,
    bool Function()? shouldCancel,
    int pageSize = 128,
  }) async {
    if (pageSize <= 0) throw ArgumentError.value(pageSize, 'pageSize');
    for (var page = 0; ; page++) {
      if (shouldCancel?.call() ?? false) return;
      final chunk = await read(page, pageSize);
      if (shouldCancel?.call() ?? false) return;
      for (var i = 0; i < chunk.length; i++) {
        onItem(page * pageSize + i, chunk[i]);
      }
      onPage?.call(chunk.length);
      if (chunk.length < pageSize) return;
      // Yield between bounded pages so UI frames and cancellation can run.
      await Future<void>.delayed(Duration.zero);
    }
  }
}
