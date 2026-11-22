import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallerydrift/semantic_lab/clip_bpe.dart';
import 'package:gallerydrift/semantic_lab/mobileclip_models.dart';

void main(){
  test('CLIP BPE special tokens, merges and fixed 77-token context',(){
    final tokenizer=ClipBpe.fromJson(jsonEncode({
      'model':{
        'type':'BPE',
        'vocab':{
          '<|startoftext|>':1,'<|endoftext|>':2,
          'c':3,'a':4,'t</w>':5,'ca':6,'cat</w>':7,
        },
        'merges':['c a','ca t</w>'],
      },
    }));
    final ids=tokenizer.encode('cat');
    expect(ids.length,77);
    expect(ids.take(3),[1,7,2]);
    expect(ids.skip(3).every((n)=>n==0),true);
  });

  test('normalization yields unit-length 512D embeddings',(){
    final vector=List<double>.filled(512,0)..[0]=3..[1]=4;
    final unit=l2Unit(vector);
    expect(unit[0],closeTo(.6,1e-9));
    expect(unit[1],closeTo(.8,1e-9));
    expect(cosine(unit,unit),closeTo(1,1e-9));
    expect(()=>l2Unit(List<double>.filled(512,0)),throwsStateError);
  });

  test('source uses dual ONNX encoders and no bundled weights',(){
    expect(MobileClipModels.files,[
      'vision_model.onnx','text_model_quantized.onnx','tokenizer.json']);
    expect(MobileClipModels.source,'felixhrdyn/mobileclip2-s0-onnx');
  });
}
