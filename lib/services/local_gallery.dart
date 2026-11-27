import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'catalog_pager.dart';

class AlbumPosition {
  const AlbumPosition({required this.album, required this.index});

  final AssetPathEntity album;
  final int index;
}

class LocalGallery {
  static const selectedKey = 'gallerydrift.selectedAlbumIds.v1';
  static const favoritesKey = 'gallerydrift.favoriteAssetIds.v1';
  static const permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(type: RequestType.common, mediaLocation: false),
  );

  /// Album position of each canvas image, captured while loading its selected
  /// folder. Duplicate assets belong to the first selected album encountered.
  final Map<String, AlbumPosition> _positions = {};

  AlbumPosition? positionFor(String assetId) => _positions[assetId];

  String albumNameFor(String assetId) =>
      _positions[assetId]?.album.name ?? '';

  /// Keep currently displayed asset positions coherent after a confirmed
  /// device-trash operation. Indexes later in that same album shift down one.
  void applyTrashed(String assetId) {
    final removed = _positions.remove(assetId);
    if (removed == null) return;
    for (final entry in _positions.entries.toList()) {
      final previous = entry.value;
      if (previous.album.id == removed.album.id &&
          previous.index > removed.index) {
        _positions[entry.key] = AlbumPosition(
          album: previous.album, index: previous.index - 1);
      }
    }
  }

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
      PhotoManager.getAssetPathList(hasAll: false, type: RequestType.common);

  /// Scan every item in chosen folders, one bounded MediaStore page at a time.
  /// Only metadata is collected; image bytes remain lazy and cached separately.
  /// The position map is swapped atomically after a complete successful pass,
  /// preventing taps from using partially updated folder indices.
  Future<List<AssetEntity>> selectedPhotos(
    Set<String> selectedIds, {
    void Function(int done, int total)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    if (selectedIds.isEmpty) {
      _positions.clear();
      return <AssetEntity>[];
    }
    final paths = await albums();
    final chosen = paths.where((p) => selectedIds.contains(p.id)).toList();
    final counts = await Future.wait(
      chosen.map((p) => p.assetCountAsync));
    final total = counts.fold<int>(0, (sum, n) => sum + n);
    final result = <AssetEntity>[];
    final newPositions = <String, AlbumPosition>{};
    var scanned = 0;
    for (final path in chosen) {
      if (shouldCancel?.call() ?? false) return <AssetEntity>[];
      await CatalogPager.scan<AssetEntity>(
        read: (page, size) => path.getAssetListPaged(page: page, size: size),
        shouldCancel: shouldCancel,
        onItem: (index, item) {
          if (!newPositions.containsKey(item.id)) {
            newPositions[item.id] = AlbumPosition(album: path, index: index);
            result.add(item);
          }
        },
        onPage: (count) {
          scanned += count;
          onProgress?.call(scanned, total);
        },
      );
    }
    if (shouldCancel?.call() ?? false) return <AssetEntity>[];
    _positions
      ..clear()
      ..addAll(newPositions);
    onProgress?.call(scanned, total);
    return result;
  }
}
