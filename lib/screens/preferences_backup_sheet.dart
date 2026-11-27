import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization.dart';
import '../services/preferences_backup.dart';

Future<bool?> showPreferencesBackupSheet(BuildContext context) =>
  showModalBottomSheet<bool>(
    context:context,isScrollControlled:true,useSafeArea:true,
    builder:(context)=>const _BackupSheet());

class _BackupSheet extends StatefulWidget {
  const _BackupSheet();
  @override State<_BackupSheet> createState()=>_BackupSheetState();
}

class _BackupSheetState extends State<_BackupSheet> {
  final _text=TextEditingController();
  Map<String,Object?>? _preview;
  String? _error;
  bool _working=false;

  @override void dispose(){_text.dispose();super.dispose();}

  Future<void> _copy() async {
    setState(()=>_working=true);
    try {
      final raw=PreferencesArchive.encode(
        await PreferencesArchive.snapshot());
      await Clipboard.setData(ClipboardData(text:raw));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(GalleryLocale.t('backupCopied'))));
    } catch(e) {
      if(mounted)setState(()=>_error=e.toString());
    } finally {
      if(mounted)setState(()=>_working=false);
    }
  }

  void _inspect() {
    try {
      setState(() {
        _preview=PreferencesArchive.decode(_text.text);
        _error=null;
      });
    } catch(e) {
      setState(() {_preview=null;_error=e.toString();});
    }
  }

  Future<void> _restore() async {
    if (_preview==null || _working) return;
    final confirmed = await showDialog<bool>(context:context,
      builder:(ctx)=>AlertDialog(
        title:Text(GalleryLocale.t('restorePreferences')),
        content:Text(GalleryLocale.t('restoreConfirm')),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:Text(GalleryLocale.t('cancel'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:Text(GalleryLocale.t('restorePreferences'))),
        ]));
    if(confirmed!=true || !mounted)return;
    setState(()=>_working=true);
    try {
      await PreferencesArchive.restore(_text.text);
      if(mounted)Navigator.pop(context,true);
    } catch(e) {
      if(mounted)setState(()=>_error=e.toString());
    } finally {
      if(mounted)setState(()=>_working=false);
    }
  }

  @override Widget build(BuildContext context) => Padding(
    padding:EdgeInsets.fromLTRB(20,18,20,
      MediaQuery.viewInsetsOf(context).bottom+24),
    child:SizedBox(height:MediaQuery.sizeOf(context).height*.7,
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(GalleryLocale.t('backupPreferences'),
          style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),
        Text(GalleryLocale.t('backupDetails')),
        const SizedBox(height:12),
        OutlinedButton.icon(onPressed:_working?null:_copy,
          icon:const Icon(Icons.copy_all_outlined),
          label:Text(GalleryLocale.t('copyBackup'))),
        const SizedBox(height:12),
        Expanded(child:TextField(
          controller:_text,expands:true,maxLines:null,minLines:null,
          onChanged:(_){if(_preview!=null)setState(()=>_preview=null);},
          decoration:InputDecoration(
            border:const OutlineInputBorder(),
            hintText:GalleryLocale.t('pasteBackup')))),
        if(_error!=null) Text(_error!,
          style:const TextStyle(color:Colors.orangeAccent)),
        if(_preview!=null) Padding(
          padding:const EdgeInsets.symmetric(vertical:8),
          child:Text(
            '${(_preview!['selected'] as List).length} '+GalleryLocale.t('albums')+
            ' · ${(_preview!['favorites'] as List).length} '+GalleryLocale.t('favorites'),
            style:const TextStyle(fontWeight:FontWeight.w600))),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:OutlinedButton(
            onPressed:_working?null:_inspect,
            child:Text(GalleryLocale.t('inspectBackup')))),
          const SizedBox(width:12),
          Expanded(child:FilledButton(
            onPressed:_preview==null || _working?null:_restore,
            child:Text(GalleryLocale.t('restorePreferences')))),
        ]),
      ])));
}
