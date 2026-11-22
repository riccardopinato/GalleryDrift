import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../widgets/local_photo.dart';
import 'background_semantic.dart';
import 'mobileclip_models.dart';
import 'semantic_index.dart';

/// Independent noncommercial research screen. Never says that embeddings
/// are object detections or that a similarity score is a probability.
class SemanticLabScreen extends StatefulWidget {
  const SemanticLabScreen({
    super.key,required this.assets,required this.onPhoto,
  });
  final List<AssetEntity> assets;
  final ValueChanged<AssetEntity> onPhoto;

  @override State<SemanticLabScreen> createState()=>_SemanticLabScreenState();
}

class _SemanticLabScreenState extends State<SemanticLabScreen> {
  final _query=TextEditingController();
  bool _accepted=false,_downloaded=false,_busy=false;
  String _status='Caricamento stato locale';
  String? _error;
  SemanticProgress? _indexProgress;
  List<SemanticHit> _hits=[];
  Timer? _poll;

  @override void initState(){
    super.initState();
    _refreshStatus();
    _poll=Timer.periodic(const Duration(seconds:12),(_)=>_refreshStatus());
  }

  @override void dispose(){
    _poll?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try{
      final ready=await MobileClipModels.ready();
      final accepted=await SemanticBackground.accepted();
      final progress=await SemanticIndex.progress(widget.assets);
      if(mounted)setState((){
        _downloaded=ready;_accepted=accepted;_indexProgress=progress;
        if(!_busy)_status=ready?'Modello pronto (download locale)' :
          'Pesi non presenti; nessuna immagine inviata online';
      });
    }catch(e){
      if(mounted)setState(()=>_error=e.toString());
    }
  }

  Future<void> _accept() async {
    await SemanticBackground.accept();
    if(mounted)setState(()=>_accepted=true);
  }

  Future<void> _download() async {
    if(!_accepted || _busy)return;
    setState((){
      _busy=true;_error=null;_status='Download pesi di ricerca';
    });
    try{
      await MobileClipModels.install(onProgress:(file,done,total){
        if(mounted)setState((){
          final pct=total==null?'':(100*done/total).toStringAsFixed(0)+'%';
          _status=file+' '+pct+' ('+
            (done/1048576).toStringAsFixed(1)+' MiB)';
        });
      });
      await SemanticBackground.schedule();
      if(mounted)setState(()=>_downloaded=true);
    }catch(e){
      if(mounted)setState(()=>_error='Download: '+e.toString());
    }finally{
      if(mounted)setState(()=>_busy=false);
      await _refreshStatus();
    }
  }

  Future<void> _indexNow() async {
    if(_busy || !_downloaded || !_accepted)return;
    setState(()=>_busy=true);
    try{
      final pending=await SemanticIndex.indexBatch(widget.assets,limit:12,
        onProgress:(done,total,errors){
          if(mounted)setState(()=>_status='Foto elaborate: '+
            done.toString()+'/'+total.toString()+
            ' · Errori: '+errors.toString());
        });
      if(pending)await SemanticBackground.schedule();
    }catch(e){
      if(mounted)setState(()=>_error='Indicizzazione: '+e.toString());
    }finally{
      if(mounted)setState(()=>_busy=false);
      await _refreshStatus();
    }
  }

  Future<void> _search() async {
    if(_busy || !_downloaded || _query.text.trim().isEmpty)return;
    setState((){
      _busy=true;_error=null;_status='Calcolo similarità semantica';
    });
    try{
      final results=await SemanticIndex.search(_query.text,widget.assets);
      if(mounted)setState(()=>_hits=results);
    }catch(e){
      if(mounted)setState(()=>_error='Ricerca: '+e.toString());
    }finally{
      if(mounted)setState(()=>_busy=false);
      await _refreshStatus();
    }
  }

  Future<void> _eraseWeights() async {
    if(_busy)return;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>
      AlertDialog(
        title:const Text('Rimuovere il modello?'),
        content:const Text('Vengono eliminati solo i file del modello '
          'scaricato da AI Lab. Le fotografie restano intatte.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Annulla')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Rimuovi')),
        ]));
    if(yes!=true || !mounted)return;
    setState(()=>_busy=true);
    try{
      await MobileClipModels.remove();
      if(mounted)setState(()=>_downloaded=false);
    }catch(e){
      if(mounted)setState(()=>_error=e.toString());
    }finally{
      if(mounted)setState(()=>_busy=false);
      await _refreshStatus();
    }
  }

  @override Widget build(BuildContext context){
    final progress=_indexProgress;
    final byId={for(final a in widget.assets)a.id:a};
    return Scaffold(
      appBar:AppBar(
        title:const Text('Gallery Drift · AI Lab'),
        actions:[
          IconButton(
            tooltip:'Aggiorna avanzamento',
            onPressed:_busy?null:_refreshStatus,
            icon:const Icon(Icons.refresh)),
        ]),
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(16,12,16,8),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('MobileCLIP2-S0 · test sperimentale',
              style:TextStyle(fontSize:17,fontWeight:FontWeight.w700)),
            const SizedBox(height:7),
            const Text('Solo ricerca scientifica non commerciale. '
              'La licenza Apple NON consente lo sviluppo di prodotti commerciali '
              'con questi pesi. Il modello non è incluso nell’APK.',
              style:TextStyle(fontSize:12,color:Colors.amberAccent)),
            const SizedBox(height:8),
            if(!_accepted) OutlinedButton.icon(
              onPressed:_busy?null:_accept,
              icon:const Icon(Icons.check_circle_outline),
              label:const Text('Confermo: solo ricerca non commerciale')),
            if(_accepted && !_downloaded) FilledButton.icon(
              onPressed:_busy?null:_download,
              icon:const Icon(Icons.download_outlined),
              label:const Text('Scarica modello (~107 MB)')),
            if(_downloaded) Row(children:[
              Expanded(child:FilledButton.icon(
                onPressed:_busy?null:_indexNow,
                icon:const Icon(Icons.psychology_outlined),
                label:const Text('Analizza 12 foto ora'))),
              IconButton(tooltip:'Rimuovi modello',
                onPressed:_busy?null:_eraseWeights,
                icon:const Icon(Icons.delete_outline)),
            ]),
            if(_busy)const LinearProgressIndicator(),
            Text(_status,style:const TextStyle(fontSize:11,
              color:Colors.white70)),
            if(progress!=null) Text(
              'Indicizzate: '+progress.complete.toString()+' / '+
              progress.total.toString()+
              ' · Errori: '+progress.failed.toString(),
              style:const TextStyle(fontSize:11,color:Colors.white70)),
            if(_error!=null)Text(_error!,
              style:const TextStyle(color:Colors.orangeAccent,fontSize:12)),
            const SizedBox(height:9),
            Row(children:[
              Expanded(child:TextField(
                controller:_query,
                textInputAction:TextInputAction.search,
                onSubmitted:(_)=>_search(),
                decoration:const InputDecoration(
                  prefixIcon:Icon(Icons.search),
                  hintText:'gatto, tramonto, auto rossa...',
                  border:OutlineInputBorder()))),
              const SizedBox(width:8),
              IconButton.filled(
                tooltip:'Cerca per similarità',
                onPressed:_downloaded && !_busy?_search:null,
                icon:const Icon(Icons.arrow_forward)),
            ]),
            const SizedBox(height:6),
            const Text('I risultati sono ordinati per similarità coseno: '
              'NON sono un riconoscimento verificato e il punteggio '
              'NON è una probabilità.',
              style:TextStyle(fontSize:11,color:Colors.white54)),
          ])),
        Expanded(child: !_downloaded
          ? const Center(child:Text('Attiva il modello per effettuare '
              'ricerche semantiche offline.',textAlign:TextAlign.center))
          : _hits.isEmpty
            ? const Center(child:Text('Nessun risultato mostrato. '
                'Indicizza un lotto e cerca una descrizione.',
                textAlign:TextAlign.center))
            : ListView.builder(itemCount:_hits.length,
                itemBuilder:(context,i){
                  final hit=_hits[i];
                  final asset=byId[hit.id];
                  if(asset==null)return const SizedBox.shrink();
                  return ListTile(
                    leading:SizedBox(width:58,height:58,
                      child:LocalPhoto(asset:asset)),
                    title:Text(asset.title??asset.id,maxLines:1),
                    subtitle:Text('Similarità: '+
                      hit.score.toStringAsFixed(3)),
                    onTap:(){
                      Navigator.of(context).pop();
                      widget.onPhoto(asset);
                    },
                  );
                })),
      ])),
    );
  }
}
