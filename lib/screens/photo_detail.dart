import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../localization.dart';
import '../widgets/local_photo.dart';

class PhotoDetail extends StatefulWidget {
  const PhotoDetail({super.key, required this.asset, required this.favorite,
    required this.onFavorite, required this.onTrashed});
  final AssetEntity asset;
  final bool favorite;
  final Future<void> Function(AssetEntity) onFavorite;
  final VoidCallback onTrashed;

  @override State<PhotoDetail> createState() => _PhotoDetailState();
}

class _PhotoDetailState extends State<PhotoDetail> {
  late bool _favorite = widget.favorite;
  bool _busy = false;

  Future<void> _trash() async {
    if (!Platform.isAndroid) return;
    final yes = await showDialog<bool>(context:context,
      builder:(ctx)=>AlertDialog(
        title: Text(GalleryLocale.t('trash')),
        content: Text(GalleryLocale.t('confirmTrash')),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child: Text(GalleryLocale.t('cancel'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child: Text(GalleryLocale.t('trash'))),
        ],
      ));
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final moved = await PhotoManager.editor.android.moveToTrash([widget.asset]);
      if (!mounted) return;
      if (moved.contains(widget.asset.id)) {
        widget.onTrashed();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(GalleryLocale.t('error'))));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(GalleryLocale.t('error'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:const Color(0xFF101117),
    appBar:AppBar(backgroundColor:const Color(0xFF101117),
      title:Text(widget.asset.title ?? GalleryLocale.t('info')),
      actions:[
        IconButton(tooltip:GalleryLocale.t('favorites'),
          onPressed: _busy ? null : () async {
            await widget.onFavorite(widget.asset);
            if (mounted) setState(() => _favorite = !_favorite);
          },
          icon:Icon(_favorite ? Icons.favorite : Icons.favorite_border)),
        if (Platform.isAndroid) IconButton(
          tooltip:GalleryLocale.t('trash'), onPressed:_busy ? null : _trash,
          icon:const Icon(Icons.delete_outline)),
      ]),
    body:Column(children:[
      Expanded(child: Center(child:LocalPhoto(
        key:ValueKey(widget.asset.id), asset:widget.asset,contain:true))),
      Padding(padding:const EdgeInsets.all(18),
        child:Text('${GalleryLocale.t('date')}: ${widget.asset.createDateTime.toLocal()}'
          '   ·   ${GalleryLocale.t('size')}: ${widget.asset.width}×${widget.asset.height}',
          style:const TextStyle(color:Colors.white60))),
    ]),
  );
}
