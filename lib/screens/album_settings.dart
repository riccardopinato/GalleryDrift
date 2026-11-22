import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../localization.dart';
import '../services/local_gallery.dart';

Future<bool?> showAlbumSettings(BuildContext context, LocalGallery source,
    Set<String> current) => showModalBottomSheet<bool>(
  context: context, isScrollControlled: true, useSafeArea: true,
  builder: (_) => _AlbumSettings(source: source, selected: current),
);

class _AlbumSettings extends StatefulWidget {
  const _AlbumSettings({required this.source, required this.selected});
  final LocalGallery source;
  final Set<String> selected;
  @override State<_AlbumSettings> createState() => _AlbumSettingsState();
}

class _AlbumSettingsState extends State<_AlbumSettings> {
  late final Set<String> _selected = {...widget.selected};
  List<AssetPathEntity> _albums = [];
  bool _busy = false;
  bool _limited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _readAccessible();
  }

  Future<void> _readAccessible() async {
    setState(() => _busy = true);
    try {
      final state = await widget.source.permission();
      final albums = state.hasAccess ? await widget.source.albums() :
          <AssetPathEntity>[];
      if (!mounted) return;
      setState(() { _albums = albums; _limited = state.isLimited; _error = state.hasAccess ? null :
        GalleryLocale.t('denied'); _busy = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString(); _busy = false; });
    }
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      final state = await widget.source.askPermission();
      if (!mounted) return;
      if (state.hasAccess) {
        await _readAccessible();
      } else {
        setState(() { _busy = false; _error = GalleryLocale.t('denied'); });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() { _busy = false; _error = error.toString(); });
    }
  }

  Future<void> _save() async {
    await widget.source.saveSelected(_selected);
    if (mounted) Navigator.pop(context,true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20,16,20,20),
      child: SizedBox(height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(GalleryLocale.t('settings'),
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:12),
          Text(GalleryLocale.t('albums'),
            style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height:12),
          OutlinedButton.icon(onPressed: _busy ? null : _request,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(GalleryLocale.t('grant'))),
          if (_limited) TextButton.icon(
            onPressed: _busy ? null : () async {
              await PhotoManager.presentLimited(type: RequestType.common);
              if (mounted) await _readAccessible();
            },
            icon: const Icon(Icons.collections_outlined),
            label: Text(GalleryLocale.t('limitedAccess'))),
          if (_error != null) Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
          if (_busy) const LinearProgressIndicator(),
          if (!_busy && _albums.isNotEmpty) Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text('${_albums.length} · ${_selected.length}',
              style: const TextStyle(fontSize: 12, color: Colors.white70))),
          Expanded(child: _albums.isEmpty ?
            Center(child: Text(GalleryLocale.t('none'))) :
            ListView.builder(
              itemCount: _albums.length,
              itemBuilder: (context,index) {
                final album = _albums[index];
                return CheckboxListTile(
                  value: _selected.contains(album.id),
                  title: Text(album.name, maxLines: 2),
                  onChanged: (value) => setState(() {
                    if (value == true) { _selected.add(album.id); }
                    else { _selected.remove(album.id); }
                  }),
                );
              })),
          const SizedBox(height:12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context,false),
              child: Text(GalleryLocale.t('cancel')))),
            const SizedBox(width:12),
            Expanded(child: FilledButton(onPressed: _busy ? null : _save,
              child: Text(GalleryLocale.t('apply')))),
          ]),
          const SizedBox(height:18),
          Text(GalleryLocale.t('language')),
          Wrap(spacing:4, children: [
            for (final code in GalleryLocale.codes) ChoiceChip(
              label: Text(GalleryLocale.names[code]!),
              selected: GalleryLocale.current.value == code,
              onSelected: (_) async {
                await GalleryLocale.select(code);
                if (mounted) setState((){});
              }),
          ]),
          TextButton.icon(icon: const Icon(Icons.privacy_tip_outlined),
            onPressed: () => showDialog<void>(context:context,
              builder:(ctx)=> AlertDialog(
                title: Text(GalleryLocale.t('privacy')),
                content: SingleChildScrollView(
                  child: Text(GalleryLocale.t('privacyBody'))),
                actions: [TextButton(onPressed:()=>Navigator.pop(ctx),
                  child: Text(GalleryLocale.t('close')))])),
            label: Text(GalleryLocale.t('privacy'))),
        ]),
      ),
    ));
  }
}
