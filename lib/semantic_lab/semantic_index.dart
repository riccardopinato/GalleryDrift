import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sqflite/sqflite.dart';

import 'mobileclip_models.dart';

class SemanticHit {
  const SemanticHit(this.id,this.score);
  final String id;
  final double score;
}

class SemanticProgress {
  const SemanticProgress(this.total,this.complete,this.failed);
  final int total,complete,failed;
}

/// Local embeddings only (2 KiB per image). Does not upload media.
/// Each WorkManager job works in a bounded batch, saving per-image results.
abstract final class SemanticIndex {
  static Future<Database> _open() async {
    final root=await getApplicationSupportDirectory();
    return openDatabase(root.path+'/gallerydrift_semantic_lab.sqlite',
      version:1,onCreate:(db,version) async {
        await db.execute(
          'CREATE TABLE embeddings ('
          'id TEXT PRIMARY KEY, revision INTEGER NOT NULL, '
          'model TEXT NOT NULL, vector BLOB, failed INTEGER NOT NULL)');
        await db.execute(
          'CREATE INDEX embedding_model_idx ON embeddings(model)');
      });
  }

  static Future<RandomAccessFile> _lock() async {
    final dir=await getApplicationSupportDirectory();
    final file=File(dir.path+'/gallerydrift_semantic_lab.lock');
    final handle=await file.open(mode:FileMode.append);
    await handle.lock(FileLock.exclusive);
    return handle;
  }

  static Future<void> _unlock(RandomAccessFile file) async {
    await file.unlock();
    await file.close();
  }

  static Uint8List _pack(List<double> vector) =>
    Uint8List.fromList(
      Uint8List.view(Float32List.fromList(vector).buffer));

  static List<double> _unpack(List<int> bytes) {
    if(bytes.length!=2048)throw const FormatException('Invalid vector length');
    final view=Uint8List.fromList(bytes).buffer.asFloat32List();
    return view.toList(growable:false);
  }

  static Future<SemanticProgress> progress(List<AssetEntity> visible) async {
    final photos={for(final a in visible)
      if(a.type==AssetType.image) a.id:a.modifiedDateTime.millisecondsSinceEpoch};
    final db=await _open();
    try{
      final rows=await db.query('embeddings',
        columns:['id','revision','failed','model']);
      var success=0,failed=0;
      for(final row in rows){
        if(row['model']!=MobileClipModels.revision)continue;
        final id=row['id'] as String;
        if(photos[id]!=row['revision'])continue;
        if(row['failed']==1)failed++;else success++;
      }
      return SemanticProgress(photos.length,success,failed);
    }finally{await db.close();}
  }

  static Future<void> reconcile(List<AssetEntity> visible) async {
    final allowed={for(final photo in visible)
      if(photo.type==AssetType.image)photo.id};
    final db=await _open();
    try{
      final rows=await db.query('embeddings',columns:['id']);
      final toDelete=<String>[
        for(final row in rows)
          if(!allowed.contains(row['id']))row['id'] as String,
      ];
      // Revoked permissions and deselected folders must drop cached vectors.
      for(final id in toDelete){
        await db.delete('embeddings',where:'id = ?',whereArgs:[id]);
      }
    }finally{await db.close();}
  }

  static Future<bool> indexBatch(
    List<AssetEntity> visible,{
    int limit=12,
    void Function(int complete,int total,int failures)? onProgress,
  }) async {
    if(limit<=0 || limit>64)throw ArgumentError.value(limit,'limit');
    if(!await MobileClipModels.ready())return false;
    final lock=await _lock();
    final db=await _open();
    MobileClipSession? session;
    try{
      final images=visible.where((a)=>a.type==AssetType.image).toList();
      final recorded=await db.query('embeddings',
        columns:['id','revision','model']);
      final revisions={
        for(final r in recorded)
          if(r['model']==MobileClipModels.revision)
            r['id'] as String:r['revision'] as int,
      };
      final pending=[
        for(final a in images)
          if(revisions[a.id]!=a.modifiedDateTime.millisecondsSinceEpoch)a,
      ];
      if(pending.isEmpty)return false;
      session=await MobileClipSession.vision();
      final batch=pending.take(limit).toList();
      var finished=0,failures=0;
      for(final photo in batch){
        try{
          final data=await photo.thumbnailDataWithSize(
            const ThumbnailSize(512,512),quality:90);
          if(data==null || data.isEmpty){
            throw const FormatException('Missing accessible thumbnail');
          }
          final vector=await session.imageEmbedding(data);
          await db.insert('embeddings',{
            'id':photo.id,
            'revision':photo.modifiedDateTime.millisecondsSinceEpoch,
            'model':MobileClipModels.revision,
            'vector':_pack(vector),
            'failed':0,
          },conflictAlgorithm:ConflictAlgorithm.replace);
        }catch(_){
          failures++;
          await db.insert('embeddings',{
            'id':photo.id,
            'revision':photo.modifiedDateTime.millisecondsSinceEpoch,
            'model':MobileClipModels.revision,
            'vector':null,
            'failed':1,
          },conflictAlgorithm:ConflictAlgorithm.replace);
        }
        finished++;
        onProgress?.call(finished,batch.length,failures);
      }
      return pending.length>batch.length;
    }finally{
      if(session!=null)await session.close();
      await db.close();
      await _unlock(lock);
    }
  }

  /// CLIP scores represent RELATIVE similarity, not verified category labels
  /// and never a calibrated probability that an object is present.
  static Future<List<SemanticHit>> search(String phrase,
      List<AssetEntity> visible,{int limit=100}) async {
    if(phrase.trim().isEmpty || !await MobileClipModels.ready())return [];
    final prompts=englishPrompt(phrase);
    final session=await MobileClipSession.text();
    late final List<double> text;
    try{text=await session.textEmbedding(prompts);}
    finally{await session.close();}
    final rev={
      for(final asset in visible)
        if(asset.type==AssetType.image)
          asset.id:asset.modifiedDateTime.millisecondsSinceEpoch,
    };
    final db=await _open();
    try{
      final rows=await db.query('embeddings',
        columns:['id','revision','model','vector','failed']);
      final hits=<SemanticHit>[];
      for(final r in rows){
        if(r['model']!=MobileClipModels.revision ||
           r['failed']!=0 || r['vector'] is! Uint8List)continue;
        final id=r['id'] as String;
        if(rev[id]!=r['revision'])continue;
        final image=_unpack(r['vector'] as Uint8List);
        final score=cosine(image,text);
        if(score.isFinite)hits.add(SemanticHit(id,score));
      }
      hits.sort((a,b)=>b.score.compareTo(a.score));
      return hits.take(limit).toList();
    }finally{await db.close();}
  }

  static String englishPrompt(String input) {
    final raw=input.toLowerCase().trim()
      .replaceAll('animale domestico','pet')
      .replaceAll('animali domestici','pets');
    const italian={
      'gatto':'cat','gatti':'cats','gattino':'kitten','felino':'cat',
      'cane':'dog','cani':'dogs','animale domestico':'pet',
      'tramonto':'sunset','mare':'sea','spiaggia':'beach',
      'montagna':'mountain','bicicletta':'bicycle',
      'macchina':'car','auto':'car','persone':'people',
      'albero':'tree','fiore':'flower','cibo':'food',
      'nero':'black','nera':'black','rossa':'red','rosso':'red',
      'bianco':'white','bianca':'white','blu':'blue',
      'divano':'sofa','letto':'bed','finestra':'window',
      'sul':'on','sulla':'on','su':'on','sotto':'under',
      'pet':'pet','pets':'pets','vicino':'near','presso':'near',
    };
    final translated=<String>[];
    for(final word in raw.split(RegExp(r'\s+'))){
      translated.add(italian[word]??word);
    }
    var english=translated.join(' ');
    // Basic noun/adjective order for common Italian visual queries.
    english=english.replaceAllMapped(
      RegExp(r'\b(cat|dog|kitten) (black|white|red|blue)\b'),
      (match)=>match.group(2)!+' '+match.group(1)!);
    if(RegExp(r'^(?:(?:black|white|red|blue) )?(?:cat|dog|kitten|pet)\b')
        .hasMatch(english)) {
      english='a '+english;
    }
    return 'a photo of '+english;
  }
}
