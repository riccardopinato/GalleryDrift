import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android MediaStore is authoritative; this app does NOT hold deleted files.
/// The platform may restrict visibility of trashed media owned by other apps.
@immutable
class SystemTrashItem {
  const SystemTrashItem({
    required this.uri,
    required this.name,
    required this.mime,
    required this.bytes,
    required this.expires,
  });

  final String uri, name, mime;
  final int bytes;
  final int? expires;

  bool get isVideo => mime.startsWith('video/');
  DateTime? get expiresAt => expires == null || expires == 0
      ? null : DateTime.fromMillisecondsSinceEpoch(expires! * 1000);

  factory SystemTrashItem.fromMap(Map<Object?, Object?> map) =>
      SystemTrashItem(
        uri: map['uri'] as String,
        name: map['name'] as String? ?? '',
        mime: map['mime'] as String? ?? '',
        bytes: (map['bytes'] as num?)?.toInt() ?? 0,
        expires: (map['expires'] as num?)?.toInt(),
      );
}

abstract final class SystemTrash {
  static const channel = MethodChannel('gallerydrift/system_trash');

  static Future<bool> supported() async =>
      await channel.invokeMethod<bool>('supported') ?? false;

  static Future<List<SystemTrashItem>> list() async {
    final rows = await channel.invokeMethod<List<dynamic>>('list');
    return [
      for (final row in rows ?? const <dynamic>[])
        SystemTrashItem.fromMap(Map<Object?,Object?>.from(row as Map)),
    ];
  }

  static Future<Uint8List?> thumbnail(String uri) =>
      channel.invokeMethod<Uint8List>('thumbnail', {'uri': uri});

  static Future<Set<String>> restore(Set<String> uris) =>
      _mutate(uris, 'restore');

  static Future<Set<String>> deleteForever(Set<String> uris) =>
      _mutate(uris, 'deleteForever');

  static Future<Set<String>> _mutate(Set<String> uris, String operation) async {
    if (uris.isEmpty || uris.length > 100) {
      throw ArgumentError('Select between 1 and 100 entries');
    }
    final verified = await channel.invokeMethod<List<dynamic>>(
      operation, {'uris': uris.toList()});
    return (verified ?? const <dynamic>[]).whereType<String>().toSet();
  }
}
