import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization.dart';
import 'local_gallery.dart';

/// Human-portable preferences only: never includes gallery image bytes,
/// Android permissions, ML model cache, secrets, or native app identity.
abstract final class PreferencesArchive {
  static const format = 'gallerydrift.preferences';
  static const version = 1;
  static const maxArchiveChars = 8 * 1024 * 1024;
  static const cameraKeys = <String>[
    'gallerydrift.camera.all.x',
    'gallerydrift.camera.all.y',
    'gallerydrift.camera.all.zoom',
    'gallerydrift.camera.all.autoSpeed',
    'gallerydrift.camera.favorites.x',
    'gallerydrift.camera.favorites.y',
    'gallerydrift.camera.favorites.zoom',
    'gallerydrift.camera.favorites.autoSpeed',
  ];

  static Future<Map<String, Object?>> snapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return <String,Object?>{
      'selected': prefs.getStringList(LocalGallery.selectedKey) ?? <String>[],
      'favorites': prefs.getStringList(LocalGallery.favoritesKey) ?? <String>[],
      'locale': GalleryLocale.current.value,
      for (final key in cameraKeys)
        if (prefs.containsKey(key)) key: prefs.get(key),
    };
  }

  static String encode(Map<String, Object?> values) {
    _validate(values);
    final data = jsonEncode(values);
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'data': values,
      'sha256': sha256.convert(utf8.encode(data)).toString(),
    });
  }

  static Map<String, Object?> decode(String text) {
    if (text.length > maxArchiveChars) {
      throw const FormatException('Backup troppo grande');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map || decoded['format'] != format ||
        decoded['version'] != version ||
        decoded['data'] is! Map ||
        decoded['sha256'] is! String) {
      throw const FormatException('Formato backup non valido');
    }
    final data = Map<String,Object?>.from(decoded['data'] as Map);
    if (sha256.convert(utf8.encode(jsonEncode(data))).toString() !=
        decoded['sha256']) {
      throw const FormatException('Checksum del backup non valido');
    }
    _validate(data);
    return data;
  }

  static void _validate(Map<String,Object?> data) {
    final allowed = {'selected','favorites','locale',...cameraKeys};
    if (data.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Chiave sconosciuta nel backup');
    }
    for (final field in ['selected','favorites']) {
      final items = data[field];
      if (items is! List || items.length > 100000 ||
          items.any((v) => v is! String || v.isEmpty || v.length > 512)) {
        throw FormatException('Elenco non valido: '+field);
      }
    }
    if (!GalleryLocale.codes.contains(data['locale'])) {
      throw const FormatException('Lingua non valida');
    }
    for (final key in cameraKeys) {
      if (!data.containsKey(key)) continue;
      final value = data[key];
      if (key.endsWith('.autoSpeed')) {
        if (value is! int || !const [25,50,75,100].contains(value)) {
          throw const FormatException('Velocita non valida');
        }
      } else {
        if (value is! num || !value.isFinite ||
            value.abs() > 100000000 ||
            (key.endsWith('.zoom') && (value < 0.55 || value > 2.7))) {
          throw const FormatException('Camera non valida');
        }
      }
    }
  }

  static Future<void> restore(String raw) async {
    // Fail before writing anything when the schema or digest is wrong.
    final incoming = decode(raw);
    final previous = await snapshot();
    try {
      await _apply(incoming);
    } catch (_) {
      // Restore the previous local preferences on an interrupted write.
      await _apply(previous);
      rethrow;
    }
  }

  static Future<void> _apply(Map<String,Object?> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(LocalGallery.selectedKey,
      List<String>.from(data['selected'] as List));
    await prefs.setStringList(LocalGallery.favoritesKey,
      List<String>.from(data['favorites'] as List));
    for (final key in cameraKeys) {
      if (!data.containsKey(key)) {
        await prefs.remove(key);
      } else if (key.endsWith('.autoSpeed')) {
        await prefs.setInt(key, data[key] as int);
      } else {
        await prefs.setDouble(key, (data[key] as num).toDouble());
      }
    }
    await GalleryLocale.select(data['locale'] as String);
  }
}
