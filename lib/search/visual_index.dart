import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// Explicit, foreground, cancelable on-device image labeling.
class VisualIndex extends ChangeNotifier {
  static const modelVersion = 'mlkit-base-v1';
  final Map<String, _Record> _entries = {};
  bool _loaded = false;
  bool _running = false;
  bool _cancel = false;
  bool _disposed = false;
  int progress = 0;
  int total = 0;
  int errors = 0;

  bool get isRunning => _running;
  int get cachedCount => _entries.length;

  void _emit() { if (!_disposed) notifyListeners(); }

  List<String> labelsFor(AssetEntity asset) {
    final record = _entries[asset.id];
    return record != null &&
        record.revision == asset.modifiedDateTime.millisecondsSinceEpoch
      ? record.labels : const [];
  }

  Future<File> _file() async {
    final root = await getApplicationSupportDirectory();
    return File('${root.path}/gallerydrift_visual_index_v1.json');
  }

  Future<void> load() async {
    if (_loaded) return;
    final f = await _file();
    if (!await f.exists()) { _loaded = true; return; }
    try {
      final json = jsonDecode(await f.readAsString());
      if (json is! Map || json['model'] != modelVersion ||
          json['assets'] is! Map) {
        _loaded = true; return;
      }
      for (final row in (json['assets'] as Map).entries) {
        final value = row.value;
        if (row.key is! String || value is! Map ||
            value['revision'] is! int || value['labels'] is! List) continue;
        _entries[row.key as String] = _Record(
          value['revision'] as int,
          (value['labels'] as List).whereType<String>().toList());
      }
    } catch (_) {
      // Corrupt derived cache is ignored; users can re-index safely.
      _entries.clear();
    }
    _loaded = true;
    _emit();
  }

  Future<void> _persist() async {
    final file = await _file();
    final staging = File('${file.path}.tmp');
    await staging.writeAsString(jsonEncode({
      'model': modelVersion,
      'assets': {
        for (final entry in _entries.entries)
          entry.key: {'revision': entry.value.revision,
            'labels': entry.value.labels},
      },
    }), flush:true);
    // Never deliberately delete the only valid index before the replacement.
    // Android rename replaces destination on the supported filesystems.
    await staging.rename(file.path);
  }

  Future<void> index(List<AssetEntity> selectedPhotos) async {
    if (_running) return;
    await load();
    _running = true; _cancel = false; errors = 0; progress = 0;
    // The entire selected MediaStore catalog is eligible; label only images.
    // Videos are searchable by filename and album metadata.
    final images = selectedPhotos.where(
      (asset) => asset.type == AssetType.image).toList();
    final allowed = images.map((a) => a.id).toSet();
    _entries.removeWhere((id, _) => !allowed.contains(id));
    final work = images.where((asset) {
      final record = _entries[asset.id];
      return record == null ||
        record.revision != asset.modifiedDateTime.millisecondsSinceEpoch;
    }).toList();
    total = work.length;
    _emit();
    final cache = await getTemporaryDirectory();
    final tmp = File('${cache.path}/gallerydrift_mlkit_input.jpg');
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.45));
    try {
      for (final asset in work) {
        if (_cancel) break;
        try {
          final bytes = await asset.thumbnailDataWithSize(
            const ThumbnailSize(384,384), quality: 83);
          if (bytes == null || bytes.isEmpty) {
            errors++;
          } else {
            await tmp.writeAsBytes(bytes, flush:true);
            final labels = await labeler.processImage(
              InputImage.fromFilePath(tmp.path));
            _entries[asset.id] = _Record(
              asset.modifiedDateTime.millisecondsSinceEpoch,
              labels.where((label) => label.confidence >= 0.45)
                .map((label) => label.label.toLowerCase()).toList());
          }
        } catch (_) {
          errors++;
        } finally {
          if (await tmp.exists()) await tmp.delete();
          progress++;
          if (progress % 80 == 0) {
            await _persist();
          }
          if (progress % 8 == 0 || progress == total) _emit();
        }
      }
    } finally {
      await labeler.close();
      if (await tmp.exists()) await tmp.delete();
      await _persist();
      _running = false;
      _emit();
    }
  }

  void cancel() { _cancel = true; }

  Future<void> clear() async {
    cancel();
    if (_running) return;
    _entries.clear();
    final f = await _file();
    if (await f.exists()) await f.delete();
    _emit();
  }

  void forget(String id) => forgetAll([id]);

  void forgetAll(Iterable<String> ids) {
    var changed=false;
    for (final id in ids) {
      if (_entries.remove(id) != null) changed=true;
    }
    if (changed) {
      _emit();
      unawaited(_persist());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel = true;
    super.dispose();
  }
}

class _Record {
  const _Record(this.revision, this.labels);
  final int revision;
  final List<String> labels;
}
