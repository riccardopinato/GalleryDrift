import 'package:flutter_test/flutter_test.dart';
import 'package:gallerydrift/search/combined_search.dart';

void main() {
  const docs = [
    PhotoSearchDocument(id:'1', filename:'IMG_0123.jpg', album:'Compleanno',
      labels:['Cat','Pet','Mammal']),
    PhotoSearchDocument(id:'2', filename:'fullmoon.jpg', album:'Estate',
      labels:['Moon','Night']),
    PhotoSearchDocument(id:'3', filename:'IMG_2244.jpg', album:'Parigi 2026',
      labels:['City','Building']),
    PhotoSearchDocument(id:'4', filename:'IMG_0004.jpg', album:'Camper in Toscana',
      labels:['Caravan','Camping']),
    PhotoSearchDocument(id:'5', filename:'My Cat Luna.jpg', album:'Animali',
      labels:[]),
    PhotoSearchDocument(id:'6', filename:'IMG_0019.jpg', album:'New York 2024',
      labels:['Skyscraper']),
  ];

  test('cat, moon and camper can be found from labels and filenames', () {
    expect(PhotoSearch.find('gatto',docs).map((x)=>x.document.id),['5','1']);
    expect(PhotoSearch.find('luna',docs).map((x)=>x.document.id),['5','2']);
    expect(PhotoSearch.find('camper',docs).map((x)=>x.document.id),['4']);
  });
  test('folders and multiword place names are always searchable', () {
    expect(PhotoSearch.find('Parigi',docs).single.document.id,'3');
    expect(PhotoSearch.find('new york',docs).single.document.id,'6');
    expect(PhotoSearch.find('Compleanno',docs).single.document.id,'1');
  });
  test('no false match for unknown city in visual labels', () {
    expect(PhotoSearch.find('Tokyo',docs),isEmpty);
  });
  test('query requires all words, stays accent-insensitive', () {
    expect(PhotoSearch.find('gatto compleanno',docs).single.document.id,'1');
    expect(PhotoSearch.normalize('Città  PARIGI'),'citta parigi');
    expect(PhotoSearch.find('',docs),isEmpty);
  });
}
