import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'clip_bpe.dart';

/// Apple MobileCLIP2-S0 weights: research-only; not redistributed in APK.
/// The app downloads the three files from their public repository only
/// AFTER an explicit research-license acknowledgement.
abstract final class MobileClipModels {
  static const String source='felixhrdyn/mobileclip2-s0-onnx';
  static const String revision='mobileclip2-s0-hybrid-research-v1';
  static const files=<String>[
    'vision_model.onnx',
    'text_model_quantized.onnx',
    'tokenizer.json',
  ];
  static const _maximum=<String,int>{
    'vision_model.onnx':100*1024*1024,
    'text_model_quantized.onnx':150*1024*1024,
    'tokenizer.json':8*1024*1024,
  };

  static Future<Directory> folder() async {
    final dir=Directory((await getApplicationSupportDirectory()).path+
      '/mobileclip2_s0_research');
    if(!await dir.exists())await dir.create(recursive:true);
    return dir;
  }

  static Future<bool> ready() async {
    final dir=await folder();
    for(final name in files) {
      final f=File(dir.path+'/'+name);
      if(!await f.exists() || await f.length()<
          (name.endsWith('.onnx') ? 1024*1024 : 1024))return false;
    }
    return true;
  }

  static Future<void> remove() async {
    final dir=await folder();
    if(await dir.exists())await dir.delete(recursive:true);
  }

  static Future<void> install({
    required void Function(String name,int done,int? total) onProgress,
  }) async {
    final dir=await folder();
    final client=HttpClient()..connectionTimeout=const Duration(seconds:30);
    try {
      for(final name in files){
        final target=File(dir.path+'/'+name);
        if(await target.exists() && await target.length()>1024*1024 &&
            name!='tokenizer.json')continue;
        if(await target.exists() && name=='tokenizer.json' &&
            await target.length()>1024)continue;
        final tmp=File(target.path+'.downloading');
        try {
          if(await tmp.exists())await tmp.delete();
          final url=Uri.https('huggingface.co','/'+source+
            '/resolve/main/'+name,{'download':'true'});
          final request=await client.getUrl(url);
          final response=await request.close();
          if(response.statusCode!=HttpStatus.ok){
            throw HttpException('Model download HTTP '+response.statusCode.toString());
          }
          final max=_maximum[name]!;
          var bytes=0;
          final sink=tmp.openWrite();
          try {
            await for(final chunk in response) {
              bytes+=chunk.length;
              if(bytes>max)throw const FormatException('Model file exceeds safety size');
              sink.add(chunk);
              onProgress(name,bytes,
                response.contentLength>0 ? response.contentLength : null);
            }
            await sink.flush();
          } finally {
            await sink.close();
          }
          if(bytes < (name.endsWith('.onnx') ? 1024*1024 : 1024)){
            throw const FormatException('Model file is too short');
          }
          if(name=='tokenizer.json'){
            ClipBpe.fromJson(await tmp.readAsString());
          }
          await tmp.rename(target.path);
        }catch(_){
          if(await tmp.exists())await tmp.delete();
          rethrow;
        }
      }
      // Local content hashes are diagnostic only; an unpinned upstream
      // checksum is NOT evidence of an authenticated model release.
      final digest=<String,String>{};
      for(final name in files){
        digest[name]=sha256.convert(await File(dir.path+'/'+name).readAsBytes())
          .toString();
      }
      await File(dir.path+'/local_digests.json')
        .writeAsString(jsonEncode(digest));
    } finally {
      client.close(force:true);
    }
  }
}

List<double> l2Unit(List<num> values) {
  var norm=0.0;
  for(final n in values){norm+=n*n;}
  if(norm<=0 || !norm.isFinite)throw StateError('Invalid zero/NaN embedding');
  final root=math.sqrt(norm);
  return values.map((v)=>v/root).toList(growable:false);
}

double cosine(List<num> a,List<num> b){
  if(a.length!=512 || b.length!=512){
    throw ArgumentError('Expected matching 512-dimensional vectors');
  }
  var score=0.0;
  for(var i=0;i<512;i++){score+=a[i]*b[i];}
  return score;
}

/// Only thumbnail pixels are decoded, no full-resolution media copies.
Float32List mobileClipPixels(Uint8List bytes){
  final image=img.decodeImage(bytes);
  if(image==null)throw const FormatException('Unsupported image codec');
  final factor=256.0/math.min(image.width,image.height);
  final resized=img.copyResize(image,
    width:math.max(256,(image.width*factor).round()),
    height:math.max(256,(image.height*factor).round()),
    interpolation:img.Interpolation.linear);
  final left=(resized.width-256)~/2;
  final top=(resized.height-256)~/2;
  final data=Float32List(3*256*256);
  const mean=<double>[0.48145466,0.4578275,0.40821073];
  const std=<double>[0.26862954,0.26130258,0.27577711];
  for(var y=0;y<256;y++){
    for(var x=0;x<256;x++){
      final pixel=resized.getPixel(x+left,y+top);
      final at=y*256+x;
      data[at]=(pixel.r.toDouble()/255-mean[0])/std[0];
      data[65536+at]=(pixel.g.toDouble()/255-mean[1])/std[1];
      data[131072+at]=(pixel.b.toDouble()/255-mean[2])/std[2];
    }
  }
  return data;
}

class MobileClipSession {
  MobileClipSession._(this._session,this._tokenizer);
  final OrtSession _session;
  final ClipBpe? _tokenizer;

  static Future<MobileClipSession> vision() async {
    final dir=await MobileClipModels.folder();
    final runtime=OnnxRuntime();
    final session=await runtime.createSession(dir.path+'/vision_model.onnx',
      options:OrtSessionOptions(intraOpNumThreads:2,
        interOpNumThreads:1,providers:[OrtProvider.CPU]));
    return MobileClipSession._(session,null);
  }
  static Future<MobileClipSession> text() async {
    final dir=await MobileClipModels.folder();
    final tokenizer=ClipBpe.fromJson(await
      File(dir.path+'/tokenizer.json').readAsString());
    final runtime=OnnxRuntime();
    final session=await runtime.createSession(
      dir.path+'/text_model_quantized.onnx',
      options:OrtSessionOptions(intraOpNumThreads:2,
        interOpNumThreads:1,providers:[OrtProvider.CPU]));
    return MobileClipSession._(session,tokenizer);
  }

  Future<List<double>> imageEmbedding(Uint8List thumbnail) async {
    final input=await OrtValue.fromList(
      mobileClipPixels(thumbnail),[1,3,256,256]);
    return _infer(input);
  }

  Future<List<double>> textEmbedding(String prompt) async {
    if(_tokenizer==null)throw StateError('Text model not loaded');
    final ids=Int64List.fromList(_tokenizer.encode(prompt));
    final input=await OrtValue.fromList(ids,[1,77]);
    return _infer(input);
  }

  Future<List<double>> _infer(OrtValue input) async {
    try {
      if(_session.inputNames.length!=1 || _session.outputNames.isEmpty){
        throw StateError('Unexpected ONNX model signature');
      }
      final output=await _session.run({_session.inputNames.first:input});
      try{
        final values=await output[_session.outputNames.first]!.asFlattenedList();
        if(values.length!=512)throw StateError('Unexpected embedding dimensions');
        return l2Unit(values.cast<num>());
      }finally{
        for(final tensor in output.values){await tensor.dispose();}
      }
    }finally{
      await input.dispose();
    }
  }

  Future<void> close()=>_session.close();
}
