import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../localization.dart';
import '../services/album_pager.dart';
import '../widgets/local_photo.dart';

/// Open a photo from the infinite canvas and swipe within ONLY its album.
/// The album is loaded by stable MediaStore indices, not from the random
/// mosaic order, and only nearby page ranges are retained in memory.
class PhotoDetail extends StatefulWidget {
  const PhotoDetail({
    super.key,
    required this.asset,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTrashed,
    this.album,
    this.initialIndex = 0,
  });

  final AssetEntity asset;
  final AssetPathEntity? album;
  final int initialIndex;
  final bool Function(AssetEntity) isFavorite;
  final Future<void> Function(AssetEntity) onFavorite;
  final Future<void> Function(AssetEntity) onTrashed;

  @override
  State<PhotoDetail> createState() => _PhotoDetailState();
}

class _PhotoDetailState extends State<PhotoDetail> {
  late final PageController _controller;
  AlbumPager<AssetEntity>? _pager;
  late int _index;
  late int _count;
  AssetEntity? _current;
  bool _busy = false;
  bool _countError = false;
  final Map<int, Future<AssetEntity?>> _requests = {};

  @override
  void initState() {
    super.initState();
    _index = widget.album == null ? 0 : math.max(0, widget.initialIndex);
    _count = _index + 1;
    _current = widget.asset;
    _controller = PageController(initialPage: _index);
    if (widget.album != null) {
      _pager = AlbumPager<AssetEntity>(
        readRange: (start, end) =>
            widget.album!.getAssetListRange(start: start, end: end),
      )..prime(_index, widget.asset);
      _loadCount();
    }
  }

  Future<void> _loadCount() async {
    try {
      final count = await widget.album!.assetCountAsync;
      if (!mounted) return;
      // Never drop the opened image while an album is changing externally.
      setState(() => _count = math.max(_index + 1, count));
    } catch (_) {
      if (mounted) setState(() => _countError = true);
    }
  }

  Future<AssetEntity?> _assetAt(int index) => _requests.putIfAbsent(
    index,
    () => _pager?.at(index) ?? Future<AssetEntity?>.value(widget.asset),
  );

  Future<void> _activate(int index) async {
    if (index == _index) return;
    setState(() {
      _index = index;
      _current = null;
    });
    _pager?.retainNear(index);
    _requests.removeWhere((key, _) => (key - index).abs() > 3);
    try {
      final asset = await _assetAt(index);
      if (!mounted || index != _index) return;
      setState(() => _current = asset);
    } catch (_) {
      if (mounted && index == _index) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(GalleryLocale.t('error'))));
      }
    }
  }

  Future<void> _favorite() async {
    final target = _current;
    if (target == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onFavorite(target);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(GalleryLocale.t('error'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _trash() async {
    if (!Platform.isAndroid || _busy || _current == null) return;
    final target = _current!;
    final yes = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text(GalleryLocale.t('trash')),
        content: Text(GalleryLocale.t('confirmTrash')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(GalleryLocale.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(GalleryLocale.t('trash'))),
        ],
      ));
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final moved = await PhotoManager.editor.android.moveToTrash([target]);
      if (!mounted) return;
      if (moved.contains(target.id)) {
        await widget.onTrashed(target);
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(GalleryLocale.t('error'))));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(GalleryLocale.t('error'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pager?.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _current;
    final title = active?.title ?? widget.album?.name ??
      GalleryLocale.t('info');
    final albumName = widget.album?.name ?? GalleryLocale.t('info');
    return Scaffold(
      backgroundColor: const Color(0xFF101117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101117),
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
            Text(albumName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text('${_index + 1} / $_count · $title',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        actions: [
          IconButton(
            tooltip: GalleryLocale.t('favorites'),
            onPressed: _busy || active == null ? null : _favorite,
            icon: Icon(active != null && widget.isFavorite(active)
              ? Icons.favorite : Icons.favorite_border)),
          if (Platform.isAndroid) IconButton(
            tooltip: GalleryLocale.t('trash'),
            onPressed: _busy || active == null ? null : _trash,
            icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Column(children: [
        if (_countError) Padding(
          padding: const EdgeInsets.all(8),
          child: Text(GalleryLocale.t('albumReadError'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.orangeAccent))),
        Expanded(child: PageView.builder(
          key: const Key('gallerydrift-album-pageview'),
          controller: _controller,
          itemCount: _count,
          onPageChanged: _activate,
          itemBuilder: (context, index) => FutureBuilder<AssetEntity?>(
            future: _assetAt(index),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: TextButton(
                  onPressed: () => setState(() => _requests.remove(index)),
                  child: Text(GalleryLocale.t('retry'))));
              }
              final photo = snapshot.data;
              if (photo == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return Center(child: LocalPhoto(
                key: ValueKey(photo.id), asset: photo, contain: true));
            },
          ),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: Column(children: [
            if (active != null) Text(
              '${GalleryLocale.t('date')}: ${active.createDateTime.toLocal()}'
              '   ·   ${GalleryLocale.t('size')}: ${active.width}×${active.height}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
            if (_count > 1) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(GalleryLocale.t('albumSwipeHint'),
                style: const TextStyle(color: Colors.white38, fontSize: 10))),
          ]),
        ),
      ]),
    );
  }
}
