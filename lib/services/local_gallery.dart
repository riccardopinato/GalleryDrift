import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlbumPosition {
  const AlbumPosition({required this.album, required this.index});

  final AssetPathEntity album;
  final int index;
}

class LocalGallery {
  static const selectedKey = 'gallerydrift.selectedAlbumIds.v1';
  static const favoritesKey = 'gallerydrift.favoriteAssetIds.v1';
  static const permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(type: RequestType.image, mediaLocation: false),
  );

  /// Album position of each canvas image, captured while loading its selected
  /// folder. Duplicate assets belong to the first selected album encountered.
  final Map<String, AlbumPosition> _positions = {};

  AlbumPosition? positionFor(String assetId) => _positions[assetId];

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

  /// Canvas bootstrap: bounded at 800 images per album to avoid freezing
  /// on very large galleries. The album detail viewer independently pages
  /// through the FULL folder using MediaStore range queries.
  Future<List<AssetEntity>> selectedPhotos(Set<String> selectedIds) async {
    _positions.clear();
    if (selectedIds.isEmpty) return [];
    final paths = await albums();
    final result = <AssetEntity>[];
    final seen = <String>{};
    for (final path in paths) {
      if (!selectedIds.contains(path.id)) continue;
      for (var page = 0; page < 8; page++) {
        final chunk = await path.getAssetListPaged(page: page, size: 100);
        for (var i = 0; i < chunk.length; i++) {
          final item = chunk[i];
          if (seen.add(item.id)) {
            result.add(item);
            _positions[item.id] = AlbumPosition(
              album: path, index: page * 100 + i);
          }
        }
        if (chunk.length < 100) break;
      }
    }
    return result;
  }
}
