import 'package:flutter_test/flutter_test.dart';
import 'package:gallerydrift/services/catalog_pager.dart';

void main() {
  test('indexes complete album beyond 800 without truncation or reordering', () async {
    final entries = <int>[];
    final progress = <int>[];
    await CatalogPager.scan<int>(
      pageSize: 128,
      read: (page, size) async => [
        for (var i = page * size; i < (page + 1) * size && i < 2001; i++) i,
      ],
      onItem: (index, asset) {
        expect(asset, index);
        entries.add(asset);
      },
      onPage: progress.add,
    );
    expect(entries.length, 2001);
    expect(entries[800], 800);
    expect(entries.last, 2000);
    expect(progress.reduce((a, b) => a + b), 2001);
  });

  test('cancellation stops subsequent pages and does not read ahead', () async {
    var cancelled = false;
    var calls = 0;
    final observed = <int>[];
    await CatalogPager.scan<int>(
      pageSize: 10,
      read: (page, size) async {
        calls++;
        return List.generate(size, (i) => page * size + i);
      },
      onItem: (index, asset) => observed.add(asset),
      onPage: (_) => cancelled = true,
      shouldCancel: () => cancelled,
    );
    expect(calls, 1);
    expect(observed.length, 10);
  });

  test('empty page and invalid size terminate safely', () async {
    var count = 0;
    await CatalogPager.scan<int>(
      read: (page, size) async => <int>[],
      onItem: (_, __) => count++,
    );
    expect(count, 0);
    await expectLater(CatalogPager.scan<int>(
      pageSize: 0,
      read: (p, n) async => [],
      onItem: (_, __) {},
    ), throwsArgumentError);
  });
}
