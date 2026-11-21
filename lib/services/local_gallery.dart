import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalGallery {
  static const selectedKey = 'gallerydrift.selectedAlbumIds.v1';
  static const favoritesKey = 'gallerydrift.favoriteAssetIds.v1';
  static const permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(type: RequestType.image, mediaLocation: false),
  );

  Future<Set<String>> selected() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(selectedKey) ?? const []).toSet();
  }

  Future<void> saveSelected(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(selectedKey, ids.toList()..sort());
  }

  Future<Set<String>> favorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(favoritesKey) ?? const []).toSet();
  }

  Future<void> saveFavorites(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(favoritesKey, ids.toList()..sort());
  }

  Future<PermissionState> permission() =>
      PhotoManager.getPermissionState(requestOption: permissionOption);

  Future<PermissionState> askPermission() =>
      PhotoManager.requestPermissionExtend(requestOption: permissionOption);

  Future<List<AssetPathEntity>> albums() =>
      PhotoManager.getAssetPathList(hasAll: false, type: RequestType.image);

  /// Initial bounded batch to avoid loading an entire 50k photo library.
  /// This is an MVP limitation, NOT a complete paginated library index.
  Future<List<AssetEntity>> selectedPhotos(Set<String> selectedIds) async {
    if (selectedIds.isEmpty) return [];
    final paths = await albums();
    final result = <AssetEntity>[];
    final seen = <String>{};
    for (final path in paths) {
      if (!selectedIds.contains(path.id)) continue;
      for (var page = 0; page < 8; page++) {
        final chunk = await path.getAssetListPaged(page: page, size: 100);
        for (final item in chunk) {
          if (seen.add(item.id)) result.add(item);
        }
        if (chunk.length < 100) break;
      }
    }
    return result;
  }
}
