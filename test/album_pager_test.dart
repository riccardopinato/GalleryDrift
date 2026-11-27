import 'package:flutter_test/flutter_test.dart';
import 'package:gallerydrift/services/album_pager.dart';

void main() {
  test('page reader preserves album order beyond 800 without full loading', () async {
    final ranges = <String>[];
    final pager = AlbumPager<int>(
      pageSize: 64,
      readRange: (start, end) async {
        ranges.add('$start:$end');
        return [for (var i = start; i < end && i < 1601; i++) i];
      },
    );
    expect(await pager.at(0), 0);
    expect(await pager.at(799), 799);
    expect(await pager.at(800), 800);
    expect(await pager.at(1600), 1600);
    expect(await pager.at(1601), isNull);
    expect(ranges.length, lessThanOrEqualTo(5));
  });

  test('seeding the tapped image avoids a redundant first query', () async {
    var loads = 0;
    final pager = AlbumPager<String>(
      pageSize: 4,
      readRange: (start, end) async {
        loads++;
        return [for (var i = start; i < end; i++) 'image-$i'];
      },
    )..prime(300, 'selected-image');
    expect(await pager.at(300), 'selected-image');
    expect(loads, 0);
    expect(await pager.at(301), 'image-301');
    expect(await pager.at(302), 'image-302');
    expect(loads, 1);
    pager.retainNear(301);
    expect(await pager.at(301), 'image-301');
    expect(loads, 1);
    pager.clear();
    expect(await pager.at(300), 'image-300');
    expect(loads, 2);
  });

  test('prefetch at boundary warms exactly the next page once', () async {
    final ranges = <String>[];
    final pager = AlbumPager<int>(pageSize: 4, readRange: (start, end) async {
      ranges.add('$start:$end');
      return [for (var i = start; i < end; i++) i];
    });
    await pager.prefetchNext(1, totalCount: 11);
    expect(ranges, isEmpty);
    await pager.prefetchNext(2, totalCount: 11);
    expect(ranges, ['4:8']);
    await pager.prefetchNext(3, totalCount: 11);
    expect(await pager.at(5), 5);
    expect(ranges, ['4:8']);
  });

  test('prefetch never crosses album bounds or forces empty reads', () async {
    var calls = 0;
    final pager = AlbumPager<int>(pageSize: 4, readRange: (start, end) async {
      calls++;
      return [for (var i = start; i < end; i++) i];
    });
    for (final index in [-1, 0, 3, 4, 500]) {
      await pager.prefetchNext(index, totalCount: 4);
    }
    await pager.prefetchNext(6, totalCount: 0);
    expect(calls, 0);
    await pager.prefetchNext(7, totalCount: 9);
    expect(calls, 1);
    expect(await pager.at(8), 8);
    expect(calls, 1);
  });

  test('failed prefetch is evicted and foreground read can retry', () async {
    var calls = 0;
    final pager = AlbumPager<int>(pageSize: 4, readRange: (start, end) async {
      calls++;
      if (calls == 1) throw StateError('transient MediaStore error');
      return [for (var i = start; i < end; i++) i];
    });
    await expectLater(pager.prefetchNext(3, totalCount: 12), throwsStateError);
    expect(await pager.at(4), 4);
    expect(calls, 2);
  });

  test('transient read error can be retried', () async {
    var fail = true;
    final pager = AlbumPager<int>(readRange: (start, end) async {
      if (fail) throw StateError('MediaStore temporarily unavailable');
      return [for (var i = start; i < end; i++) i];
    });
    await expectLater(pager.at(0), throwsStateError);
    fail = false;
    expect(await pager.at(0), 0);
    expect(await pager.at(-1), isNull);
  });
}
