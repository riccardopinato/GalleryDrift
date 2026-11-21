import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:drift_core/drift_core.dart';
import 'package:photo_manager/photo_manager.dart';
import 'localization.dart';
import 'services/local_gallery.dart';
import 'screens/album_settings.dart';
import 'screens/photo_detail.dart';
import 'widgets/local_photo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GalleryLocale.initialize();
  PaintingBinding.instance.imageCache.maximumSize = 110;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 * 1024 * 1024;
  runApp(const GalleryDriftApp());
}

class GalleryDriftApp extends StatelessWidget {
  const GalleryDriftApp({super.key});
  @override Widget build(BuildContext context) =>
    ValueListenableBuilder<String>(valueListenable:GalleryLocale.current,
      builder:(context,language,_)=>MaterialApp(
        title:'Gallery Drift',debugShowCheckedModeBanner:false,
        theme:ThemeData(brightness:Brightness.dark,
          scaffoldBackgroundColor:const Color(0xFF101117),
          colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFFE5C8A5),
            brightness:Brightness.dark)),
        home:const GalleryHome()));
}

class GalleryHome extends StatefulWidget {
  const GalleryHome({super.key});
  @override State<GalleryHome> createState()=>_GalleryHomeState();
}

class _GalleryHomeState extends State<GalleryHome> {
  final _source=LocalGallery();
  Set<String> _selected = {};
  Set<String> _favorites = {};
  List<AssetEntity> _assets=[];
  bool _busy=true, _favoritesOnly=false;
  String? _error;

  @override void initState(){super.initState();_refresh();}

  Future<void> _refresh() async {
    setState(() {_busy=true;_error=null;});
    try {
      final selected=await _source.selected();
      final favorites=await _source.favorites();
      final access = selected.isNotEmpty ?
        await _source.permission() : null;
      final photos=selected.isEmpty ? <AssetEntity>[] :
        access != null && access.hasAccess ?
          await _source.selectedPhotos(selected) : <AssetEntity>[];
      if(!mounted)return;
      setState((){_selected=selected;_favorites=favorites;_assets=photos;
        _busy=false;_error=selected.isNotEmpty &&
          !(access?.hasAccess ?? false) ? GalleryLocale.t('denied') : null;});
    } catch(e) {
      if(!mounted)return;
      setState((){_busy=false;_error='$e';});
    }
  }

  Future<void> _openSettings() async {
    final changed=await showAlbumSettings(context,_source,_selected);
    if(mounted && changed==true) await _refresh();
  }

  Future<void> _toggleFavorite(AssetEntity photo) async {
    final next={..._favorites};
    if (!next.add(photo.id)) next.remove(photo.id);
    await _source.saveFavorites(next);
    if(mounted)setState(()=>_favorites=next);
  }

  Future<void> _openPhoto(AssetEntity photo) async {
    await Navigator.push<void>(context,MaterialPageRoute(
      builder:(context)=>PhotoDetail(asset:photo,
        favorite:_favorites.contains(photo.id),
        onFavorite:_toggleFavorite,
        onTrashed:() {setState(()=>_assets=_assets
          .where((a)=>a.id!=photo.id).toList());})));
  }

  Future<void> _search() async {
    final selected=await showSearch<AssetEntity?>(
      context:context,delegate:_LocalSearch(_assets));
    if(selected!=null && mounted)_openPhoto(selected);
  }

  @override Widget build(BuildContext context) {
    final displayed=_favoritesOnly ?
      _assets.where((x)=>_favorites.contains(x.id)).toList() : _assets;
    return Scaffold(body:Stack(fit:StackFit.expand,children:[
      if(_busy)const Center(child:CircularProgressIndicator())
      else if(_error!=null) Center(child:Padding(
        padding:const EdgeInsets.all(30),child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            Text(_error!,textAlign:TextAlign.center),
            const SizedBox(height:14),
            FilledButton(onPressed:_openSettings,
              child:Text(GalleryLocale.t('settings'))),
          ])))
      else if(displayed.isEmpty) Center(child:Padding(
        padding:const EdgeInsets.all(36),child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            const Icon(Icons.photo_library_outlined,size:52,color:Colors.white38),
            const SizedBox(height:18),
            Text(_selected.isEmpty ? GalleryLocale.t('empty') :
              GalleryLocale.t('noPhotos'),textAlign:TextAlign.center),
            const SizedBox(height:22),
            FilledButton(onPressed:_openSettings,
              child:Text(GalleryLocale.t('choose'))),
          ])))
      else DriftCanvas<AssetEntity>(
        key:ValueKey(_favoritesOnly),
        items:displayed,
        cameraKey:_favoritesOnly ? 'gallerydrift.camera.favorites' :
          'gallerydrift.camera.all',
        compactBrand:'G∞',fullBrand:'gallerydrift  ∞',
        hintText:'Gallery Drift  ·  ∞',
        recenterTooltip:'Center',
        onOpen:_openPhoto,
        tileBuilder:(context,asset,zoom)=>LocalPhoto(
          key:ValueKey(asset.id),asset:asset)),
      Positioned(top:0,left:0,right:0,child:SafeArea(bottom:false,
        child:LayoutBuilder(builder:(context,constraints){
          final w=constraints.maxWidth;
          return SizedBox(height:53,child:Stack(children:[
            Positioned(left:w/3,width:w/3,top:5,
              child:OutlinedButton.icon(onPressed:_search,
                icon:const Icon(Icons.search,size:18),
                label:Text(GalleryLocale.t('search')),
                style:OutlinedButton.styleFrom(
                  backgroundColor:const Color(0xD31B1B22),
                  foregroundColor:Colors.white))),
            Positioned(right:62,top:5,child:IconButton.filledTonal(
              tooltip:GalleryLocale.t('favorites'),
              onPressed:()=>setState(()=>_favoritesOnly=!_favoritesOnly),
              icon:Icon(_favoritesOnly ? Icons.favorite : Icons.favorite_border))),
            Positioned(right:10,top:5,child:IconButton.filledTonal(
              tooltip:GalleryLocale.t('settings'),
              onPressed:_openSettings,icon:const Icon(Icons.settings))),
          ]));
        }))),
    ]));
  }
}

class _LocalSearch extends SearchDelegate<AssetEntity?> {
  _LocalSearch(this.assets);
  final List<AssetEntity> assets;
  @override List<Widget> buildActions(BuildContext context)=>[
    IconButton(onPressed:()=>query='',icon:const Icon(Icons.close))];
  @override Widget buildLeading(BuildContext context)=>IconButton(
    onPressed:()=>close(context,null),icon:const Icon(Icons.arrow_back));
  @override Widget buildResults(BuildContext context)=>buildSuggestions(context);
  @override Widget buildSuggestions(BuildContext context) {
    final term=query.toLowerCase().trim();
    if(term.isEmpty)return const SizedBox.shrink();
    final matches=assets.where((a)=>(a.title??'').toLowerCase()
      .contains(term)).take(80).toList();
    if(matches.isEmpty)return Center(child:Text(GalleryLocale.t('noResult')));
    return ListView.builder(itemCount:matches.length,itemBuilder:(context,index){
      final photo=matches[index];
      return ListTile(
        leading:SizedBox(width:44,height:44,child:LocalPhoto(asset:photo)),
        title:Text(photo.title??photo.id),
        onTap:()=>close(context,photo));
    });
  }
}
