import 'dart:convert';

/// A small, auditable CLIP byte-level BPE tokenizer. Exact parity with the
/// downloaded HF tokenizer.json MUST be checked against reference Python
/// before claiming a validated semantic model.
class ClipBpe {
  ClipBpe._(this._vocab, this._ranks);
  final Map<String,int> _vocab;
  final Map<String,int> _ranks;
  final Map<String,List<int>> _memo={};
  static final Map<int,String> _bytes=_makeByteMap();
  static final RegExp _words=RegExp(
    r"'s|'t|'re|'ve|'m|'ll|'d|[\p{L}]+|[\p{N}]|[^\s\p{L}\p{N}]+",
    caseSensitive:false,unicode:true,
  );

  factory ClipBpe.fromJson(String text) {
    final root=jsonDecode(text);
    if(root is! Map || root['model'] is! Map) {
      throw const FormatException('Invalid tokenizer structure');
    }
    final model=root['model'] as Map;
    if(model['type']!='BPE' || model['vocab'] is! Map ||
        model['merges'] is! List) {
      throw const FormatException('Expected CLIP BPE tokenizer');
    }
    final vocab=<String,int>{};
    for(final pair in (model['vocab'] as Map).entries) {
      if(pair.key is String && pair.value is num) {
        vocab[pair.key as String]=(pair.value as num).toInt();
      }
    }
    final ranks=<String,int>{};
    final merges=model['merges'] as List;
    for(var i=0;i<merges.length;i++) {
      final m=merges[i];
      final pair=m is List && m.length==2
        ? m[0].toString()+' '+m[1].toString() : m.toString();
      ranks[pair]=i;
    }
    if(!vocab.containsKey('<|startoftext|>') ||
       !vocab.containsKey('<|endoftext|>')) {
      throw const FormatException('CLIP special tokens missing');
    }
    return ClipBpe._(vocab,ranks);
  }

  static Map<int,String> _makeByteMap() {
    final visible=<int>[
      for(var i=33;i<=126;i++) i,
      for(var i=161;i<=172;i++) i,
      for(var i=174;i<=255;i++) i,
    ];
    final chars=<int>[...visible];
    final output=<int>[...visible];
    var counter=0;
    for(var i=0;i<256;i++){
      if(!visible.contains(i)){
        chars.add(i);output.add(256+counter);counter++;
      }
    }
    return {for(var i=0;i<chars.length;i++)
      chars[i]:String.fromCharCode(output[i])};
  }

  List<int> _encodePiece(String piece) {
    final prior=_memo[piece];
    if(prior!=null)return prior;
    final chars=utf8.encode(piece).map((b)=>_bytes[b]!).toList();
    if(chars.isEmpty)return const [];
    chars[chars.length-1]+='</w>';
    while(chars.length>1) {
      var best=-1,bestRank=0x7fffffff;
      for(var i=0;i<chars.length-1;i++) {
        final rank=_ranks[chars[i]+' '+chars[i+1]];
        if(rank!=null && rank<bestRank){best=i;bestRank=rank;}
      }
      if(best<0)break;
      chars[best]=chars[best]+chars[best+1];
      chars.removeAt(best+1);
    }
    final ids=<int>[];
    for(final token in chars){
      final id=_vocab[token];
      if(id==null) {
        throw FormatException('Missing BPE token in vocab: '+token);
      }
      ids.add(id);
    }
    _memo[piece]=ids;
    if(_memo.length>1000)_memo.clear();
    return ids;
  }

  /// Exactly 77 token IDs, BOS / EOS and zero pad for the ONNX text tower.
  List<int> encode(String prompt) {
    final words=_words.allMatches(prompt.toLowerCase().trim());
    final ids=<_intAlias>[];
    // No special-token injection from input: user text is only normal prose.
    for(final word in words) {
      ids.addAll(_encodePiece(word.group(0)!));
      if(ids.length>=75)break;
    }
    final clipped=ids.take(75).toList();
    return <int>[
      _vocab['<|startoftext|>']!,...clipped,
      _vocab['<|endoftext|>']!,
      ...List<int>.filled(75-clipped.length,0),
    ];
  }
}

typedef _intAlias = int;
