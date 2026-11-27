import 'package:flutter_test/flutter_test.dart';
import 'package:gallerydrift/services/preferences_backup.dart';
import 'package:gallerydrift/services/local_gallery.dart';
import 'package:gallerydrift/localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  final example = <String,Object?>{
    'selected': <String>['albumA','albumB'],
    'favorites': <String>['asset001'],
    'locale': 'it',
    'gallerydrift.camera.all.zoom': 1.5,
    'gallerydrift.camera.all.autoSpeed': 25,
  };

  test('versioned archive round trip preserves settings and camera', () {
    final raw=PreferencesArchive.encode(example);
    expect(PreferencesArchive.decode(raw),example);
  });

  test('tampered and invalid archives are rejected before restore', () {
    final raw=PreferencesArchive.encode(example);
    expect(()=>PreferencesArchive.decode(raw.replaceFirst('asset001','assetXYZ')),
      throwsFormatException);
    expect(()=>PreferencesArchive.decode('{"version":1}'),throwsFormatException);
    expect(()=>PreferencesArchive.decode(PreferencesArchive.encode({
      ...example,'unknown':'attack',
    })),throwsFormatException);
    expect(()=>PreferencesArchive.encode({
      ...example,'gallerydrift.camera.all.zoom':100.0,
    }),throwsFormatException);
  });

  test('restores folders, favorites, language and camera after overwrite', () async {
    final prefs=await SharedPreferences.getInstance();
    await GalleryLocale.select('en');
    await prefs.setStringList(LocalGallery.selectedKey,['temporary']);
    await prefs.setStringList(LocalGallery.favoritesKey,['temp-photo']);
    final raw=PreferencesArchive.encode(example);
    await PreferencesArchive.restore(raw);
    expect(await LocalGallery().selected(),{'albumA','albumB'});
    expect(await LocalGallery().favorites(),{'asset001'});
    expect(GalleryLocale.current.value,'it');
    expect(prefs.getDouble('gallerydrift.camera.all.zoom'),1.5);
    expect(prefs.getInt('gallerydrift.camera.all.autoSpeed'),25);
    expect(prefs.getStringList(LocalGallery.selectedKey),
      ['albumA','albumB']);
    await GalleryLocale.select('en');
  });
  test('invalid checksum preserves existing preferences', () async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setStringList(LocalGallery.selectedKey,['unchanged']);
    final raw=PreferencesArchive.encode(example);
    await expectLater(PreferencesArchive.restore(
      raw.replaceFirst('asset001','corrupted')),throwsFormatException);
    expect(await LocalGallery().selected(),{'unchanged'});
  });
  test('archive cannot inject unknown preferences or wrong locale', () {
    expect(()=>PreferencesArchive.encode({...example,'locale':'xx'}),
      throwsFormatException);
    expect(()=>PreferencesArchive.encode({...example,'selected':<int>[123]}),
      throwsFormatException);
  });
}
