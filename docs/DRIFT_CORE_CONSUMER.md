# Gallery Drift — Drift Core consumer 0.1

Git source: https://github.com/riccardopinato/ArtDrift-Infinite-Art-Gallery
Pinned core source commit: 75cbc4db6e9a292a727dbabb8dacd2c13564d8d3
Package path: packages/drift_core
Consumer repo: riccardopinato/GalleryDrift

## Contract
The gallery NEVER copies Art Drift canvas code: it imports drift_core and supplies local AssetEntity tileBuilder, album list and gallerydrift.* camera/prefs namespaces. Shared canvas changes occur in Art Drift core package first; Gallery updates only the immutable dependency ref after passing CI.

## Early implementation boundaries
- Start with **zero selected albums**; no read request on first launch.
- Request photo permission from Settings explicitly, then show only the selected albums.
- Android plugin: photo_manager ^3.12.0 (Apache-2.0), platform MediaStore (photo_manager).
- Initial canvas indexing is bounded to 800 images per selected album; the album detail now has a separate paged source for browsing the entire folder. Infinite canvas discovery beyond 800, background catalog and live changes still remain to be implemented.
- Images only. On-device ML Kit common-category labeling + filename/folder search is implemented behind explicit user action; this is NOT a universal Lens-equivalent. Video playback, open-vocabulary CLIP retrieval, ads, purchases and full privacy-policy publication are not implemented.
- Favorites are app-local and not Android system favorites.
- Trash uses Android 11+ MediaStore trash via plugin and system permission confirmation. Older unsupported Android versions fail closed rather than permanently delete media.
- Play Store media access policy must be reviewed: broad READ_MEDIA_IMAGES is defensible only for sustained photo-gallery core functionality; Data Safety / hosted privacy policy not certified.

No source tests or physical QA are declared passed until GitHub CI evidence exists. This scaffold is a consumer integration, not a Store-ready release.

## 2026-11-27 shared Core update

Source: Art Drift PR #85 merged to canonical ArtDrift main as `1f7d19f91502405fe3d7d8e5538977d6117cd2ee`.
This Gallery PR updates only the immutable Git ref, without copying ArtDrift canvas implementation or accessing user photo data. The previous `pubspec.yaml` pin was `2dac51a6be98ed364d1e95983d1f330c84354ef7`; the earlier documentation had a stale `832ae259...` pin and is corrected here.
CI evidence on this exact Gallery HEAD is required before merge. Physical gesture/visual validation remains separate; no Play readiness claimed.

## G2 museum controls compatibility test (2026-11-27)

Temporary pin: Art Drift G2 Core candidate PR #106, commit `75cbc4db6e9a292a727dbabb8dacd2c13564d8d3`. No changes to Gallery-owned photo scanning, selection, deletion, lifecycle or controls. G2 callbacks are optional and `museumControls=false` by default, so Gallery should remain unchanged. After the Art PR merges, update to the exact merged canonical Art main commit before merging this consumer PR, and rerun Android CI.
