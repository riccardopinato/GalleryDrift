import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../services/local_gallery.dart';
import 'visual_index.dart';
import '../semantic_lab/background_semantic.dart';

/// Android WorkManager launches limited-size jobs even after the app exits.
/// The OS controls their timing. No uploading or remote AI provider.
abstract final class BackgroundIndexer {
  static const task='gallerydrift-label-selected-images';
  static const enabledKey='gallerydrift.autotag.enabled';
  static const jobTag='gallerydrift-autotag';
  static const _periodic='gallerydrift-autotag-periodic';
  static bool _initialized=false;

  static Future<void> initialize() async {
    if(!Platform.isAndroid || _initialized)return;
    await Workmanager().initialize(galleryIndexDispatcher);
    _initialized=true;
    final prefs=await SharedPreferences.getInstance();
    if(prefs.getBool(enabledKey) != false){
      await Workmanager().registerPeriodicTask(_periodic,task,
        frequency:const Duration(hours:6),
        constraints:Constraints(
          requiresBatteryNotLow:true,requiresStorageNotLow:true),
        tag:jobTag);
    }
  }

  static Future<bool> enabled() async {
    final p=await SharedPreferences.getInstance();
    return p.getBool(enabledKey) != false;
  }

  static Future<void> setEnabled(bool value) async {
    final p=await SharedPreferences.getInstance();
    await p.setBool(enabledKey,value);
    if(!Platform.isAndroid)return;
    if(!value){
      await Workmanager().cancelByTag(jobTag);
    }else{
      await Workmanager().registerPeriodicTask(_periodic,task,
        frequency:const Duration(hours:6),
        constraints:Constraints(requiresBatteryNotLow:true,
          requiresStorageNotLow:true),tag:jobTag);
      await schedule();
    }
  }

  static Future<void> schedule({Duration delay=Duration.zero}) async {
    if(!Platform.isAndroid || !await enabled())return;
    final minute=DateTime.now().millisecondsSinceEpoch~/60000;
    await Workmanager().registerOneOffTask(
      'gallerydrift-autotag-once-$minute',task,
      initialDelay:delay,
      constraints:Constraints(requiresBatteryNotLow:true,
        requiresStorageNotLow:true),
      existingWorkPolicy:ExistingWorkPolicy.keep,
      tag:jobTag,
    );
  }
}

@pragma('vm:entry-point')
void galleryIndexDispatcher() {
  Workmanager().executeTask((task,input) async {
    if(task==SemanticBackground.task) {
      try { return await SemanticBackground.performTask(); }
      catch(_) { return false; }
    }
    if(task!=BackgroundIndexer.task)return true;
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    if(!Platform.isAndroid || !await BackgroundIndexer.enabled())return true;
    final source=LocalGallery();
    final selected=await source.selected();
    if(selected.isEmpty)return true;
    final permission=await source.permission();
    if(!permission.hasAccess)return true;
    final photos=await source.selectedPhotos(selected);
    final index=VisualIndex();
    try{
      final pending=await index.index(photos,maxItems:VisualIndex.batchSize);
      // Do not continuously retry failures. Only missing/changed items create
      // follow-up jobs, each with a bounded amount of local ML processing.
      if(pending && await BackgroundIndexer.enabled()){
        await Workmanager().registerOneOffTask(
          'gallerydrift-autotag-continue-'
          '${DateTime.now().microsecondsSinceEpoch}',
          BackgroundIndexer.task,
          initialDelay:const Duration(seconds:45),
          constraints:Constraints(requiresBatteryNotLow:true,
            requiresStorageNotLow:true),
          tag:BackgroundIndexer.jobTag,
        );
      }
      return true;
    }catch(_){
      // Let WorkManager retry through its normal backoff policy.
      return false;
    }finally{
      index.dispose();
    }
  });
}
