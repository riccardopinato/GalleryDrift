import 'package:flutter_test/flutter_test.dart';
import 'package:gallerydrift/services/catalog_delta.dart';

void main(){
  CatalogItemRevision asset(String id,int rev)=>CatalogItemRevision(id,rev);
  test('unchanged scan preserves renderer identity and derived cache',(){
    final before=[asset('a',1),asset('b',2)];
    final diff=CatalogDelta.between(before,[asset('a',1),asset('b',2)]);
    expect(diff.changed,false);
    expect(diff.addedIds,isEmpty);
    expect(diff.invalidatedIds,isEmpty);
  });
  test('add, change and delete selectively invalidate cache',(){
    final diff=CatalogDelta.between(
      [asset('a',1),asset('b',2),asset('c',3)],
      [asset('a',2),asset('c',3),asset('d',1)]);
    expect(diff.changed,true);
    expect(diff.addedIds,{'d'});
    expect(diff.invalidatedIds,{'a','b'});
  });
  test('sort order changes even if revisions stay unchanged',(){
    final diff=CatalogDelta.between(
      [asset('x',1),asset('y',1)],[asset('y',1),asset('x',1)]);
    expect(diff.changed,true);
    expect(diff.invalidatedIds,isEmpty);
  });
}
