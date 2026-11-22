/// Local search combines folder/filename metadata and optional on-device
/// ML Kit image labels. No data or personal pictures leave the device here.
class PhotoSearchDocument {
  const PhotoSearchDocument({
    required this.id, required this.filename, required this.album,
    this.labels = const <String>[],
  });
  final String id;
  final String filename;
  final String album;
  final List<String> labels;
}

class PhotoSearchHit {
  const PhotoSearchHit(this.document, this.score, this.reasons);
  final PhotoSearchDocument document;
  final double score;
  final Set<String> reasons;
}

abstract final class PhotoSearch {
  /// ML Kit model labels are English. This small user-facing alias map lets
  /// common requests work in six interface languages. It is NOT a universal
  /// translator or a free-vocabulary image-text embedding model.
  static const Map<String, List<String>> aliases = {
    'gatto': ['cat','kitten','feline'],
    'gatti': ['cat','kitten','feline'],
    'gattino': ['cat','kitten','feline'],
    'gattini': ['cat','kitten','feline'],
    'felino': ['cat','kitten','feline'],
    'felini': ['cat','kitten','feline'],
    'chat': ['cat','kitten','feline'],
    'katze': ['cat','kitten','feline'],
    'kater': ['cat','kitten','feline'],
    'gato': ['cat','kitten','feline'],
    'gatos': ['cat','kitten','feline'],
    'felin': ['cat','kitten','feline'],
    'cane': ['dog','puppy','canine'],
    'cani': ['dog','puppy','canine'],
    'cucciolo': ['puppy','kitten'],
    'animale': ['animal','mammal','cat','dog','pet'],
    'animali': ['animal','mammal','cat','dog','pet'],
    'domestico': ['pet','cat','dog'],
    'domestici': ['pet','cat','dog'],
    'pet': ['pet','cat','dog'],
    'feline': ['cat','kitten','feline'],
    'kitten': ['cat','kitten','feline'],
    'chien': ['dog','puppy','canine'],
    'perro': ['dog'], 'hund': ['dog'], 'cao': ['dog'],
    'luna': ['moon'], 'lune': ['moon'], 'mond': ['moon'], 'lua': ['moon'],
    'casa': ['house','home'], 'maison': ['house','home'],
    'haus': ['house','home'], 'casae': ['house','home'],
    'parco': ['park','garden'], 'parc': ['park','garden'],
    'parque': ['park','garden'], 'garten': ['garden','park'],
    'macchina': ['car','automobile'], 'auto': ['car','automobile'],
    'voiture': ['car','automobile'], 'coche': ['car','automobile'],
    'wagen': ['car','automobile'],
    'camper': ['motorhome','rv','recreational vehicle','caravan','campervan'],
    'campingcar': ['motorhome','campervan'],
    'caravane': ['caravan','motorhome'],
    'spiaggia': ['beach'], 'plage': ['beach'], 'playa': ['beach'],
    'strand': ['beach'],
    'neve': ['snow'], 'neige': ['snow'], 'schnee': ['snow'],
    'montagna': ['mountain'], 'montagne': ['mountain'],
    'montana': ['mountain'], 'berg': ['mountain'],
    'mare': ['sea','ocean'], 'mer': ['sea','ocean'], 'mar': ['sea','ocean'],
    'persona': ['person','people'], 'personne': ['person','people'],
    'pessoa': ['person','people'],
    'bambino': ['child','baby'], 'bebe': ['baby','child'],
    'fiore': ['flower'], 'fleur': ['flower'], 'flor': ['flower'],
    'blume': ['flower'],
    'albero': ['tree'], 'arbre': ['tree'], 'arbol': ['tree'],
    'baum': ['tree'],
    'cibo': ['food'], 'nourriture': ['food'], 'comida': ['food'],
    'essen': ['food'],
    'animal': ['animal','mammal','pet','cat','dog'], 'tier': ['animal'],
    'uccello': ['bird'], 'oiseau': ['bird'], 'pajaro': ['bird'],
    'vogel': ['bird'],
    'bicicletta': ['bicycle','bike'], 'bici': ['bike','bicycle'],
    'velo': ['bike','bicycle'], 'fahrrad': ['bicycle','bike'],
    'ssole': ['sun'], 'sole': ['sun'], 'sol': ['sun'], 'sonne': ['sun'],
    'cielo': ['sky'], 'ciel': ['sky'], 'himmel': ['sky'], 'ceu': ['sky'],
  };

  static String normalize(String input) {
    const from = 'àáâãäåèéêëìíîïòóôõöùúûüýÿçñß';
    const to = <String>['a','a','a','a','a','a','e','e','e','e','i','i',
      'i','i','o','o','o','o','o','u','u','u','u','y','y','c','n','ss'];
    var text = input.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      text = text.replaceAll(from[i], to[i]);
    }
    return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static bool _whole(String haystack, String needle) =>
    (' $haystack ').contains(' $needle ');

  static List<PhotoSearchHit> find(
    String query, List<PhotoSearchDocument> candidates,
    {int? limit = 100}) {
    final normalized=normalize(query);
    final searchText=const {
      'animale domestico':'pet',
      'animali domestici':'pet',
      'animaux domestiques':'pet',
      'mascota':'pet',
      'haustier':'pet',
      'animal de estimacao':'pet',
      'gatto domestico':'gatto',
      'gatti domestici':'gatti',
    }[normalized] ?? normalized;
    final words = searchText.split(' ')
      .where((x)=>x.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final results = <PhotoSearchHit>[];
    final queryPhrase = searchText;
    for (final doc in candidates) {
      final name = normalize(doc.filename);
      final folder = normalize(doc.album);
      final labelTexts = doc.labels.map(normalize).toList();
      var points = 0.0;
      final reasons = <String>{};
      var allMatch = true;
      for (final token in words) {
        final candidates = [token, ...?aliases[token]];
        final inName = name.contains(token);
        final inFolder = folder.contains(token);
        final inLabels = labelTexts.any((label) => candidates.any(
          (candidate) => _whole(label, candidate) ||
            label.split(' ').contains(candidate)));
        if (!inName && !inFolder && !inLabels) {
          allMatch = false;
          break;
        }
        if (inName) { points += 8; reasons.add('filename'); }
        if (inFolder) { points += 6; reasons.add('album'); }
        if (inLabels) { points += 5; reasons.add('visual'); }
      }
      if (!allMatch) continue;
      if (name.contains(queryPhrase)) points += 7;
      if (folder.contains(queryPhrase)) points += 5;
      results.add(PhotoSearchHit(doc, points, reasons));
    }
    results.sort((a,b) {
      final s = b.score.compareTo(a.score);
      return s != 0 ? s : a.document.id.compareTo(b.document.id);
    });
    return limit == null ? results : results.take(limit).toList();
  }
}
