import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../localization.dart';
import 'local_photo.dart';

/// Loads only the opened asset, never raw bytes for the entire gallery.
/// Photo decoding scales with zoom; the underlying source remains original.
class MediaViewer extends StatefulWidget {
  const MediaViewer({super.key, required this.asset, required this.active});
  final AssetEntity asset;
  final bool active;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  final TransformationController _transform = TransformationController();
  Future<File?>? _original;
  VideoPlayerController? _player;
  bool _loading = false;
  bool _failed = false;
  int _generation = 0;
  int _decodeTier = 1;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant MediaViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _closePlayer();
      _transform.value = Matrix4.identity();
      _decodeTier = 1;
      _open();
    } else if (oldWidget.active != widget.active) {
      if (!widget.active) {
        _player?.pause();
      } else if (_player == null && widget.asset.type == AssetType.video) {
        _open();
      }
    }
  }

  void _open() {
    final generation = ++_generation;
    _failed = false;
    if (widget.asset.type == AssetType.video) {
      if (!widget.active) return;
      _loading = true;
      _initVideo(generation);
    } else {
      _original = widget.asset.originFile;
    }
  }

  Future<void> _initVideo(int generation) async {
    VideoPlayerController? controller;
    try {
      final file = await widget.asset.file;
      if (file == null) throw StateError('Video unavailable');
      if (!mounted || generation != _generation || !widget.active) return;
      controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted || generation != _generation || !widget.active) {
        await controller.dispose();
        return;
      }
      _player = controller;
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (controller != null && controller != _player) {
        await controller.dispose();
      }
      if (mounted && generation == _generation) {
        setState(() {_loading = false; _failed = true;});
      }
    }
  }

  void _closePlayer() {
    _generation++;
    final old = _player;
    _player = null;
    if (old != null) old.dispose();
  }

  void _zoomChanged() {
    final scale = _transform.value.getMaxScaleOnAxis();
    final next = scale < 1.5 ? 1 : scale < 2.7 ? 2 : scale < 4.0 ? 3 : 5;
    if (next != _decodeTier && mounted) {
      setState(() => _decodeTier = next);
    }
  }

  void _doubleTap() {
    _transform.value = _transform.value.getMaxScaleOnAxis() > 1.1
      ? Matrix4.identity() : Matrix4.diagonal3Values(2.5, 2.5, 1);
    _zoomChanged();
  }

  @override
  void dispose() {
    _generation++;
    _closePlayer();
    _transform.dispose();
    super.dispose();
  }

  Widget _image(BuildContext context) {
    return FutureBuilder<File?>(
      future: _original,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child:Text(GalleryLocale.t('mediaUnavailable')));
        }
        final file = snapshot.data;
        if (file == null) {
          return snapshot.connectionState == ConnectionState.done
            ? Center(child:Text(GalleryLocale.t('mediaUnavailable')))
            : Center(child:LocalPhoto(asset:widget.asset,contain:true));
        }
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        final logical = MediaQuery.sizeOf(context);
        final width = widget.asset.orientatedWidth;
        final height = widget.asset.orientatedHeight;
        // A zoomed picture is redecoded from the original file on demand.
        // No full-resolution copies are held for neighboring pages.
        final targetWidth = math.min(math.max(1, width),
          math.max(1, (logical.width * pixelRatio * _decodeTier).round()));
        final targetHeight = math.min(math.max(1, height),
          math.max(1, (logical.height * pixelRatio * _decodeTier).round()));
        return GestureDetector(
          onDoubleTap: _doubleTap,
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 5,
            onInteractionUpdate: (_) => _zoomChanged(),
            child: SizedBox.expand(child: Image.file(
              file, fit: BoxFit.contain,
              cacheWidth: width >= height ? targetWidth : null,
              cacheHeight: height > width ? targetHeight : null,
              errorBuilder: (context, error, stack) =>
                Center(child:Text(GalleryLocale.t('mediaUnavailable'))),
            )),
          ),
        );
      },
    );
  }

  Widget _video(BuildContext context) {
    final player = _player;
    if (_failed) {
      return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(GalleryLocale.t('mediaUnavailable')),
        TextButton(onPressed: () {
          _closePlayer();
          setState(() => _open());
        },child:Text(GalleryLocale.t('retry'))),
      ]));
    }
    if (player == null || _loading) {
      return const Center(child:CircularProgressIndicator());
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable:player,
      builder:(context,value,_) {
        final length=value.duration.inMilliseconds;
        final current=value.position.inMilliseconds.clamp(0,
          length > 0 ? length : 0);
        return Column(children:[
          Expanded(child:Center(child:AspectRatio(
            aspectRatio:value.aspectRatio > 0 ? value.aspectRatio : 16/9,
            child:VideoPlayer(player)))),
          Row(children:[
            IconButton(
              tooltip:value.isPlaying ? GalleryLocale.t('pause') :
                GalleryLocale.t('play'),
              onPressed: () => value.isPlaying ? player.pause() : player.play(),
              icon:Icon(value.isPlaying ? Icons.pause_rounded :
                Icons.play_arrow_rounded)),
            Expanded(child:Slider(
              value:length == 0 ? 0 : current.toDouble(),
              max:length == 0 ? 1 : length.toDouble(),
              onChanged:length == 0 ? null : (ms) =>
                player.seekTo(Duration(milliseconds:ms.round())))),
            Text('${value.position.inMinutes.toString().padLeft(2, '0')}'
              ':${(value.position.inSeconds % 60).toString().padLeft(2, '0')}',
              style:const TextStyle(fontSize:12)),
            const SizedBox(width:14),
          ]),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.asset.type == AssetType.video
    ? _video(context) : _image(context);
}
