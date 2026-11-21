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
