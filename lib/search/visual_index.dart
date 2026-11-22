import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// Device-only, resumable label index with a lock shared between UI and
/// WorkManager isolates. No thumbnails, images, face IDs or GPS are persisted.
class VisualIndex extends ChangeNotifier {
  static const modelVersion = 'mlkit-base-v2';
  static const batchSize = 48;
  final Map<String, _Record> _entries = {};
  bool _loaded=false, _running=false, _cancel=false, _disposed=false;
  DateTime? _lastFileWrite;
  int progress=0,total=0,errors=0;

  bool get isRunning => _running;
  int get cachedCount => _entries.values.where((r)=>!r.failed).length;
  int get taggedCount => _entries.values.where((r)=>
    !r.failed && r.labels.isNotEmpty).length;
  int get unlabeledCount => _entries.values.where((r)=>
    !r.failed && r.labels.isEmpty).length;
  int get failedCount => _entries.values.where((r)=>r.failed).length;
  int get attemptedCount => _entries.length;

  void _emit(){ if(!_disposed) notifyListeners(); }

  List<String> labelsFor(AssetEntity asset) {
    final r=_entries[asset.id];
    return r != null && !r.failed &&
      r.revision == asset.modifiedDateTime.millisecondsSinceEpoch
        ? r.labels : const [];
  }

  Future<File> _file() async {
    final directory=await getApplicationSupportDirectory();
    return File('${directory.path}/gallerydrift_visual_index_v2.json');
  }
  Future<File> _lockFile() async {
    final directory=await getApplicationSupportDirectory();
    return File('${directory.path}/gallerydrift_visual_index.lock');
  }

  static Map<String,_Record> _decode(String raw) {
    final result=<String,_Record>{};
    final root=jsonDecode(raw);
    if(root is! Map || root['model'] != modelVersion ||
        root['assets'] is! Map) return result;
    for(final row in (root['assets'] as Map).entries){
      if(row.key is! String || row.value is! Map)continue;
      final obj=row.value as Map;
      if(obj['revision'] is! int || obj['labels'] is! List)continue;
      result[row.key as String]=_Record(
        obj['revision'] as int,
        (obj['labels'] as List).whereType<String>().take(12).toList(),
        failed:obj['failed']==true,
      );
    }
    return result;
  }

  Future<Map<String,_Record>> _readDisk() async {
    final file=await _file();
    if(!await file.exists()) return <String,_Record>{};
    try { return _decode(await file.readAsString()); }
    catch(_){return <String,_Record>{};}
  }

  Future<void> refresh() async {
    final f=await _file();
    final modified=await f.exists() ? await f.lastModified() : null;
    if(_loaded && modified == _lastFileWrite) return;
    final items=await _readDisk();
    if(_disposed)return;
    _entries..clear()..addAll(items);
    _lastFileWrite=modified;
    _loaded=true;
    _emit();
  }

  Future<void> load() => refresh();

  Future<T> _locked<T>(Future<T> Function() action) async {
    final f=await _lockFile();
    final handle=await f.open(mode:FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      return await action();
    } finally {
      await handle.unlock();
      await handle.close();
    }
  }

  Future<void> _writeDisk(Map<String,_Record> data) async {
    final f=await _file();
    final tmp=File('${f.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await tmp.writeAsString(jsonEncode({
        'model':modelVersion,
        'assets':{
          for(final e in data.entries)
            e.key:{
              'revision':e.value.revision,
              'labels':e.value.labels,
              'failed':e.value.failed,
            },
        },
      }),flush:true);
      await tmp.rename(f.path);
    } finally {
      if(await tmp.exists())await tmp.delete();
    }
  }

  /// Called from a headless WorkManager isolate or from the user foreground.
  /// Image reads and inference are capped: no multi-hour one-shot task.
  /// Returns true only if more unprocessed images exist.
  Future<bool> index(List<AssetEntity> selectedPhotos,
      {int maxItems=batchSize}) async {
    if(_running)return false;
    _running=true;_cancel=false;progress=0;errors=0;
    final images=selectedPhotos.where((a)=>a.type==AssetType.image).toList();
    total=images.length;
    _emit();
    try {
      return await _locked(() async {
        final stored=await _readDisk();
        final allowed=images.map((a)=>a.id).toSet();
        stored.removeWhere((id,_)=>!allowed.contains(id));
        final pending=images.where((asset){
          final r=stored[asset.id];
          return r==null ||
            r.revision != asset.modifiedDateTime.millisecondsSinceEpoch;
        }).toList();
        final batch=pending.take(maxItems).toList();
        if(batch.isEmpty){
          await _writeDisk(stored);
          return false;
        }
        final directory=await getTemporaryDirectory();
        final temp=File('${directory.path}/gallerydrift_vision_'
          '${DateTime.now().microsecondsSinceEpoch}.jpg');
        final labeler=ImageLabeler(
          options:ImageLabelerOptions(confidenceThreshold:0.18));
        try{
          for(final asset in batch){
            if(_cancel) break;
            var failed=false;
            var labels=<String>[];
            try{
              final image=await asset.thumbnailDataWithSize(
                const ThumbnailSize(512,512),quality:90);
              if(image == null || image.isEmpty){
                failed=true;
              }else{
                await temp.writeAsBytes(image,flush:true);
                final result=await labeler.processImage(
                  InputImage.fromFilePath(temp.path));
                labels=result.where((item)=>item.confidence>=0.18)
                  .map((item)=>item.label.toLowerCase().trim())
                  .where((item)=>item.isNotEmpty).toSet().take(12).toList();
              }
            }catch(_){ failed=true; }
            finally{
              if(await temp.exists())await temp.delete();
            }
            if(_cancel)break;
            if(failed)errors++;
            stored[asset.id]=_Record(
              asset.modifiedDateTime.millisecondsSinceEpoch,
              labels,failed:failed);
            progress++;
            if(progress%12==0){
              await _writeDisk(stored);
              _emit();
            }
          }
        }finally{
          await labeler.close();
          if(await temp.exists())await temp.delete();
          await _writeDisk(stored);
        }
        _entries..clear()..addAll(stored);
        _lastFileWrite=await (await _file()).lastModified();
        _loaded=true;
        _emit();
        return pending.length>progress && !_cancel;
      });
    }finally{
      _running=false;
      _emit();
    }
  }

  void cancel(){_cancel=true;}

  Future<void> retryFailures() async {
    await _locked(() async {
      final data=await _readDisk();
      data.removeWhere((id,r)=>r.failed);
      await _writeDisk(data);
    });
    await refresh();
  }

  Future<void> clear() async {
    cancel();
    if(_running)return;
    await _locked(() async { await _writeDisk(<String,_Record>{}); });
    await refresh();
  }

  void forget(String id)=>forgetAll([id]);

  void forgetAll(Iterable<String> ids) {
    final toRemove=ids.toSet();
    if(toRemove.isEmpty)return;
    _entries.removeWhere((id,_)=>toRemove.contains(id));
    _emit();
    unawaited(_locked(() async {
      final data=await _readDisk();
      data.removeWhere((id,_)=>toRemove.contains(id));
      await _writeDisk(data);
    }).then((_)=>refresh()));
  }

  @override
  void dispose(){_cancel=true;_disposed=true;super.dispose();}
}

class _Record {
  const _Record(this.revision,this.labels,{this.failed=false});
  final int revision;
  final List<String> labels;
  final bool failed;
}
