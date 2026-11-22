import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../localization.dart';
import '../widgets/local_photo.dart';

/// The OS owns the destructive operation: this UI never directly deletes
/// filesystem paths, and updates app state only for returned successful IDs.
Future<void> showBatchSelection(BuildContext context,
  List<AssetEntity> assets,
  Future<void> Function(List<AssetEntity>) onTrashed) =>
    Navigator.push<void>(context,MaterialPageRoute(
      builder:(_)=>_BatchSelection(assets:assets,onTrashed:onTrashed)));

class _BatchSelection extends StatefulWidget {
  const _BatchSelection({required this.assets,required this.onTrashed});
  final List<AssetEntity> assets;
  final Future<void> Function(List<AssetEntity>) onTrashed;
  @override State<_BatchSelection> createState()=>_BatchSelectionState();
}

class _BatchSelectionState extends State<_BatchSelection> {
  late final List<AssetEntity> _assets=[
    for (final a in widget.assets)
      if (a.type == AssetType.image) a,
  ];
  final Set<String> _selection = {};
  bool _busy=false;
  int _moved=0;
  int _requested=0;

  void _toggle(AssetEntity asset) => setState(() {
    if (!_selection.add(asset.id)) _selection.remove(asset.id);
  });

  Future<void> _trash() async {
    if (!Platform.isAndroid || _selection.isEmpty || _busy) return;
    final yes=await showDialog<bool>(context:context,
      builder:(ctx)=>AlertDialog(
        title:Text(GalleryLocale.t('trash')),
        content:Text(GalleryLocale.t('batchConfirm')+' '+
          _selection.length.toString()),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:Text(GalleryLocale.t('cancel'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:Text(GalleryLocale.t('trash'))),
        ]));
    if (yes!=true || !mounted) return;
    setState(() {_busy=true;_moved=0;_requested=_selection.length;});
    try {
      final chosen=[
        for (final photo in _assets)
          if (_selection.contains(photo.id)) photo,
      ];
      // Keep system dialog requests small; each chunk is independently
      // verified by photo_manager's list of IDs successfully moved.
      for (var start=0;start<chosen.length;start+=50) {
        if(!mounted) break;
        final chunk=chosen.skip(start).take(50).toList();
        final existing = <AssetEntity>[];
        for(final photo in chunk) {
          if(await photo.exists) existing.add(photo);
        }
        if (existing.isEmpty) continue;
        final movedIds=await PhotoManager.editor.android.moveToTrash(existing);
        final valid=movedIds.toSet();
        final moved=existing.where((e)=>valid.contains(e.id)).toList();
        if (moved.isNotEmpty) {
          await widget.onTrashed(moved);
          _assets.removeWhere((a)=>valid.contains(a.id));
          _selection.removeAll(valid);
          if(mounted)setState(()=>_moved+=moved.length);
        }
        // If Android refused/cancelled this request, do not prompt for
        // subsequent chunks. Keep unmodified files selected for retry.
        if (moved.length!=existing.length) break;
      }
    } catch (_) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(GalleryLocale.t('error'))));
    } finally {
      if(mounted)setState(()=>_busy=false);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:const Color(0xFF101117),
    appBar:AppBar(
      title:Text(GalleryLocale.t('multiSelect')),
      backgroundColor:const Color(0xFF101117),
      actions:[
        if (_selection.isNotEmpty) TextButton(
          onPressed:_busy?null:()=>setState(()=>_selection.clear()),
          child:Text(GalleryLocale.t('clearSelection'))),
      ]),
    body:Column(children:[
      if (_busy) const LinearProgressIndicator(),
      if (_requested>0) Padding(
        padding:const EdgeInsets.all(8),
        child:Text('$_moved / $_requested · '+GalleryLocale.t('trashedCount'),
          style:const TextStyle(color:Colors.white70))),
      Expanded(child:GridView.builder(
        padding:const EdgeInsets.all(7),
        gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:3,mainAxisSpacing:5,crossAxisSpacing:5),
        itemCount:_assets.length,
        itemBuilder:(context,index) {
          final photo=_assets[index];
          final checked=_selection.contains(photo.id);
          return Semantics(
            label:photo.title??photo.id,selected:checked,
            child:InkWell(
              onTap:_busy?null:()=>_toggle(photo),
              onLongPress:_busy?null:()=>_toggle(photo),
              child:Stack(fit:StackFit.expand,children:[
                LocalPhoto(key:ValueKey(photo.id),asset:photo),
                Positioned(top:5,right:5,child:CircleAvatar(
                  radius:15,
                  backgroundColor:checked?const Color(0xFFE5C8A5):
                    const Color(0xBB22222A),
                  child:Icon(checked?Icons.check:Icons.circle_outlined,
                    size:19,color:checked?Colors.black:Colors.white))),
              ])));
        })),
      SafeArea(top:false,child:Padding(
        padding:const EdgeInsets.fromLTRB(15,7,15,12),
        child:SizedBox(width:double.infinity,child:FilledButton.icon(
          onPressed:Platform.isAndroid && !_busy && _selection.isNotEmpty
            ? _trash : null,
          icon:const Icon(Icons.delete_outline),
          label:Text(GalleryLocale.t('trash')+
            ' ('+_selection.length.toString()+')')))),
    ]),
  );
}
