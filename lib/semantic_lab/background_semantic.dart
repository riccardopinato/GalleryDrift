import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../services/local_gallery.dart';
import 'mobileclip_models.dart';
import 'semantic_index.dart';

abstract final class SemanticBackground {
  static const task='gallerydrift-mobileclip2-research-batch';
  static const tag='gallerydrift-s0-research-lab';
  static const enabledKey='gallerydrift.lab.researchAccepted';
  static Future<bool> accepted() async {
    final p=await SharedPreferences.getInstance();
    return p.getBool(enabledKey)==true;
  }
  static Future<void> accept() async {
    final p=await SharedPreferences.getInstance();
    await p.setBool(enabledKey,true);
  }
  static Future<void> schedule({Duration delay=Duration.zero}) async {
    if(!Platform.isAndroid || !await accepted() ||
        !await MobileClipModels.ready())return;
    await Workmanager().registerOneOffTask(
      'gallerydrift-semantic-'+DateTime.now().microsecondsSinceEpoch.toString(),
      task,
      initialDelay:delay,
      tag:tag,
      constraints:Constraints(requiresBatteryNotLow:true,
        requiresStorageNotLow:true),
      existingWorkPolicy:ExistingWorkPolicy.keep,
    );
  }

  static Future<bool> performTask() async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    if(!await accepted() || !await MobileClipModels.ready())return true;
    final source=LocalGallery();
    final selected=await source.selected();
    if(selected.isEmpty)return true;
    final permission=await source.permission();
    if(!permission.hasAccess)return true;
    final visible=await source.selectedPhotos(selected);
    final more=await SemanticIndex.indexBatch(visible,limit:12);
    if(more){
      await schedule(delay:const Duration(minutes:2));
    }
    return true;
  }
}
