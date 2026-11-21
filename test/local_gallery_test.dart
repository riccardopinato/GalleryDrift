import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallerydrift/services/local_gallery.dart';
import 'package:gallerydrift/localization.dart';

void main() {
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('no albums and favorites enabled by default', () async {
    final source=LocalGallery();
    expect(await source.selected(),isEmpty);
    expect(await source.favorites(),isEmpty);
    await source.saveSelected({'albumB','albumA'});
    await source.saveFavorites({'photoB','photoA'});
    expect(await source.selected(),{'albumA','albumB'});
    expect(await source.favorites(),{'photoA','photoB'});
  });
  test('six locales available; language stored independently', () async {
    expect(GalleryLocale.codes.length,6);
    await GalleryLocale.select('en');
    expect(GalleryLocale.t('settings'),'Settings');
    final prefs=await SharedPreferences.getInstance();
    expect(prefs.getString('gallerydrift.locale'),'en');
  });
}
