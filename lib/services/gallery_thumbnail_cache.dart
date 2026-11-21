import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

/// Private, short-lived thumbnail cache. No image data ever leaves the device.
/// Gallery-only: the shared Drift Core never sees private photo bytes or IDs.
class GalleryThumbnailCache {
  GalleryThumbnailCache._();
  static final instance = GalleryThumbnailCache._();

  static const int maxBytes = 12 * 1024 * 1024;
  static const int maxEntries = 90;
  static const int concurrentLoads = 4;
  static const int maxQueuedPrefetches = 28;
  static const thumbnailSize = ThumbnailSize(420, 420);

  final _loaded = LinkedHashMap<String, Uint8List>();
  final _inFlight = <String, Future<Uint8List?>>{};
  final _waiting = Queue<_ThumbnailTask>();
  int _sizeBytes = 0;
  int _active = 0;
  int _generation = 0;

  int get residentBytes => _sizeBytes;
  int get residentCount => _loaded.length;

  Uint8List? _hit(String id) {
    final bytes = _loaded.remove(id);
    if (bytes != null) _loaded[id] = bytes;
    return bytes;
  }

  Future<Uint8List?> thumbnail(AssetEntity asset, {bool prefetch = false}) {
    final hit = _hit(asset.id);
    if (hit != null) return Future.value(hit);
    final pending = _inFlight[asset.id];
    if (pending != null) return pending;
    if (prefetch && _waiting.length >= maxQueuedPrefetches) {
      return Future.value(null);
    }

    final task = _ThumbnailTask(asset, _generation);
    _inFlight[asset.id] = task.completer.future;
    if (prefetch) {
      _waiting.addLast(task);
    } else {
      // Tiles currently on screen take priority over speculative warmup.
      _waiting.addFirst(task);
    }
    _pump();
    return task.completer.future;
  }

  Future<void> prefetch(AssetEntity asset) async {
    await thumbnail(asset, prefetch: true);
  }

  void _remember(String id, Uint8List data) {
    if (data.isEmpty || data.lengthInBytes > maxBytes) return;
    final old = _loaded.remove(id);
    if (old != null) _sizeBytes -= old.lengthInBytes;
    _loaded[id] = data;
    _sizeBytes += data.lengthInBytes;
    while (_sizeBytes > maxBytes || _loaded.length > maxEntries) {
      final first = _loaded.keys.first;
      _sizeBytes -= _loaded.remove(first)!.lengthInBytes;
    }
  }

  void _pump() {
    while (_active < concurrentLoads && _waiting.isNotEmpty) {
      final request = _waiting.removeFirst();
      _active++;
      unawaited(_resolve(request));
    }
  }

  Future<void> _resolve(_ThumbnailTask request) async {
    Uint8List? bytes;
    try {
      bytes = await request.asset.thumbnailDataWithSize(
        thumbnailSize, quality: 85);
    } catch (_) {
      bytes = null;
    }
    if (request.generation == _generation) {
      if (bytes != null) _remember(request.asset.id, bytes);
      _inFlight.remove(request.asset.id);
    }
    if (!request.completer.isCompleted) request.completer.complete(bytes);
    _active--;
    _pump();
  }

  void evict(String id) {
    final old = _loaded.remove(id);
    if (old != null) _sizeBytes -= old.lengthInBytes;
  }

  /// Discard private images when album permissions/selection changes.
  void clear() {
    _generation++;
    _loaded.clear();
    _sizeBytes = 0;
    _inFlight.clear();
    for (final request in _waiting) {
      if (!request.completer.isCompleted) {
        request.completer.complete(null);
      }
    }
    _waiting.clear();
  }
}

class _ThumbnailTask {
  _ThumbnailTask(this.asset, this.generation);
  final AssetEntity asset;
  final int generation;
  final Completer<Uint8List?> completer = Completer<Uint8List?>();
}
