import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization.dart';
import '../services/system_trash.dart';

/// Reviews Android's actual system trash; it is not an imaginary app-private
/// list of deleted IDs. All irreversible operations go through OS approval.
class SystemTrashScreen extends StatefulWidget {
  const SystemTrashScreen({super.key});

  @override State<SystemTrashScreen> createState() => _SystemTrashScreenState();
}

class _SystemTrashScreenState extends State<SystemTrashScreen> {
  List<SystemTrashItem> _items = [];
  final _selected = <String>{};
  bool _loading = true;
  bool _mutating = false;
  bool _supported = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final supported = await SystemTrash.supported();
      final items = supported ? await SystemTrash.list() : <SystemTrashItem>[];
      if (!mounted) return;
      setState(() {
        _supported = supported;
        _items = items;
        _selected.removeWhere((id) => !items.any((e) => e.uri == id));
        _loading = false;
      });
    } on PlatformException catch(e) {
      if(mounted) setState(() {
        _error = e.message ?? e.code;
        _loading = false;
      });
    } catch (e) {
      if(mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _apply({required bool permanent}) async {
    if (_mutating || _selected.isEmpty) return;
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(GalleryLocale.t(permanent
          ? 'deleteForever' : 'restoreTrash')),
        content: Text(GalleryLocale.t(permanent
          ? 'confirmDeleteForever' : 'confirmRestoreTrash')
          .replaceAll('{count}', count.toString())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(GalleryLocale.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(GalleryLocale.t(permanent
              ? 'deleteForever' : 'restoreTrash'))),
        ],
      ),
    );
    if(confirmed != true || !mounted) return;
    setState(() { _mutating = true; _error = null; });
    try {
      final changed = permanent
        ? await SystemTrash.deleteForever({..._selected})
        : await SystemTrash.restore({..._selected});
      if (!mounted) return;
      _selected.removeAll(changed);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        '${changed.length} / $count · ${GalleryLocale.t('operationVerified')}')));
    } on PlatformException catch (e) {
      if(mounted)setState(() => _error = e.message ?? e.code);
    } catch (e) {
      if(mounted)setState(() => _error = e.toString());
    } finally {
      if(mounted) {
        setState(() => _mutating = false);
        await _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(GalleryLocale.t('trashReview'))),
    body: SafeArea(child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        child: Text(GalleryLocale.t('systemTrashNote'),
          style: Theme.of(context).textTheme.bodySmall),
      ),
      if (_loading) const LinearProgressIndicator(),
      if (!_supported && !_loading)
        Padding(padding: const EdgeInsets.all(14),
          child: Text(GalleryLocale.t('trashUnsupported'))),
      if (_error != null)
        Padding(padding:const EdgeInsets.all(12),
          child: Text(_error!,style:const TextStyle(color:Colors.orangeAccent))),
      if (!_loading && _supported)
        Row(children: [
          const SizedBox(width: 8),
          TextButton(
            onPressed: _mutating || _items.isEmpty ? null : () =>
              setState(() {
                if (_selected.length == _items.length) {
                  _selected.clear();
                } else {
                  _selected.addAll(_items.take(100).map((e) => e.uri));
                }
              }),
            child: Text(GalleryLocale.t('selectAll'))),
          const Spacer(),
          Text('${_items.length} · ${_selected.length}/100',
            style: const TextStyle(color:Colors.white70)),
          IconButton(tooltip:GalleryLocale.t('retry'),
            onPressed:_mutating?_noop:_reload,
            icon:const Icon(Icons.refresh_rounded)),
          const SizedBox(width:8),
        ]),
      Expanded(child: _loading
        ? const Center(child:CircularProgressIndicator())
        : _items.isEmpty ? Center(child:Padding(
            padding: const EdgeInsets.all(22),
            child:Text(GalleryLocale.t('emptySystemTrash'),
              textAlign:TextAlign.center)))
        : ListView.builder(
            itemCount:_items.length,
            itemBuilder:(context,index){
              final item=_items[index];
              final expiration=item.expiresAt;
              return CheckboxListTile(
                key: ValueKey(item.uri),
                value:_selected.contains(item.uri),
                onChanged:_mutating ? null : (checked)=>setState((){
                  if(checked == true && _selected.length < 100) {
                    _selected.add(item.uri);
                  }
                  else { _selected.remove(item.uri); }
                }),
                secondary: _TrashThumbnail(item:item),
                title: Text(item.name.isEmpty ? item.uri : item.name,
                  maxLines: 2,overflow:TextOverflow.ellipsis),
                subtitle: Text([
                  if(item.isVideo) GalleryLocale.t('video'),
                  if(expiration!=null)
                    '${GalleryLocale.t('expires')}: ${expiration.toLocal().year}'
                    '-${expiration.toLocal().month.toString().padLeft(2,'0')}'
                    '-${expiration.toLocal().day.toString().padLeft(2,'0')}',
                ].join(' · ')),
              );
            })),
      Padding(padding:const EdgeInsets.all(14),child:Row(children:[
        Expanded(child:OutlinedButton.icon(
          onPressed: _loading || _mutating || _selected.isEmpty
            ? null : ()=>_apply(permanent:false),
          icon:const Icon(Icons.restore),
          label:Text(GalleryLocale.t('restoreTrash')))),
        const SizedBox(width:10),
        Expanded(child:FilledButton.icon(
          onPressed: _loading || _mutating || _selected.isEmpty
            ? null : ()=>_apply(permanent:true),
          style:FilledButton.styleFrom(
            backgroundColor:const Color(0xFFB93434),
            foregroundColor:Colors.white),
          icon:const Icon(Icons.delete_forever_outlined),
          label:Text(GalleryLocale.t('deleteForever'),
            maxLines:2,textAlign:TextAlign.center))),
      ])),
    ])),
  );

  void _noop() {}
}

class _TrashThumbnail extends StatelessWidget {
  const _TrashThumbnail({required this.item});
  final SystemTrashItem item;

  @override
  Widget build(BuildContext context) => SizedBox(
    width:54,height:54,
    child:FutureBuilder<Uint8List?>(
      future:SystemTrash.thumbnail(item.uri),
      builder:(context,snapshot){
        if(snapshot.hasData && snapshot.data!.isNotEmpty){
          return ClipRRect(borderRadius:BorderRadius.circular(8),
            child:Image.memory(snapshot.data!,fit:BoxFit.cover));
        }
        return Icon(item.isVideo
          ? Icons.movie_creation_outlined : Icons.image_outlined,
          color:Colors.white54);
      },
    ),
  );
}
