import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/gallery_thumbnail_cache.dart';

/// Image bytes loaded on demand only for mounted tiles, not an eager full scan.
class LocalPhoto extends StatefulWidget {
  const LocalPhoto({super.key, required this.asset, this.contain = false});
  final AssetEntity asset;
  final bool contain;

  @override
  State<LocalPhoto> createState() => _LocalPhotoState();
}

class _LocalPhotoState extends State<LocalPhoto> {
  late Future<Uint8List?> _thumbnail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LocalPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id ||
        oldWidget.contain != widget.contain) _load();
  }

  void _load() {
    _thumbnail = widget.contain
        ? widget.asset.thumbnailDataWithSize(
            const ThumbnailSize(1500, 1800), quality: 85)
        : GalleryThumbnailCache.instance.thumbnail(widget.asset);
  }

  Widget _decorate(Widget image) => Stack(fit:StackFit.expand,children:[
    image,
    if (widget.asset.type == AssetType.video)
      const Center(child:DecoratedBox(
        decoration:BoxDecoration(
          color:Color(0x990A0A12),shape:BoxShape.circle),
        child:Padding(padding:EdgeInsets.all(9),
          child:Icon(Icons.play_arrow_rounded,color:Colors.white,size:25)))),
  ]);

  @override
  Widget build(BuildContext context) {
    final warm = widget.contain ? null :
        GalleryThumbnailCache.instance.peek(widget.asset.id);
    if (warm != null) {
      return _decorate(Image.memory(warm, fit: BoxFit.cover,
          gaplessPlayback: true, filterQuality: FilterQuality.low));
    }
    return _decorate(FutureBuilder<Uint8List?>(
    future: _thumbnail,
    builder: (context, snapshot) {
      if (!snapshot.hasData || snapshot.data == null) {
        return const ColoredBox(color: Color(0xFF24232A),
          child: Center(child: Icon(Icons.image_outlined,
            color: Colors.white24)));
      }
      return Image.memory(snapshot.data!,
        fit: widget.contain ? BoxFit.contain : BoxFit.cover,
        gaplessPlayback: true, filterQuality: FilterQuality.low);
    },
    ));
  }
}
