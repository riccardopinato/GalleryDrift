/// An immutable metadata delta, independent of Android APIs. Enumerate the
/// device catalog safely, then mutate app-owned caches only for truly changed
/// or removed media. Never assume MediaStore change notifications include IDs.
class CatalogItemRevision {
  const CatalogItemRevision(this.id, this.revision);
  final String id;
  final int revision;
}

class CatalogDelta {
  const CatalogDelta({
    required this.invalidatedIds,
    required this.addedIds,
    required this.changed,
  });
  final Set<String> invalidatedIds;
  final Set<String> addedIds;
  final bool changed;

  static CatalogDelta between(
      List<CatalogItemRevision> previous,
      List<CatalogItemRevision> current) {
    final before = {for(final item in previous) item.id: item.revision};
    final after = {for(final item in current) item.id: item.revision};
    final invalidated = <String>{
      for (final entry in before.entries)
        if (after[entry.key] != entry.value) entry.key,
    };
    final added = <String>{
      for (final entry in after.entries)
        if (!before.containsKey(entry.key)) entry.key,
    };
    var changed = previous.length != current.length;
    if (!changed) {
      for(var i=0;i<current.length;i++) {
        if(previous[i].id!=current[i].id ||
            previous[i].revision!=current[i].revision) {
          changed=true;
          break;
        }
      }
    }
    return CatalogDelta(
      invalidatedIds:invalidated,addedIds:added,changed:changed);
  }
}
