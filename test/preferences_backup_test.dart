import 'package:flutter_test/flutter_test.dart';
import 'package:gallerydrift/services/preferences_backup.dart';

void main() {
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

  test('archive cannot inject unknown preferences or wrong locale', () {
    expect(()=>PreferencesArchive.encode({...example,'locale':'xx'}),
      throwsFormatException);
    expect(()=>PreferencesArchive.encode({...example,'selected':<int>[123]}),
      throwsFormatException);
  });
}
