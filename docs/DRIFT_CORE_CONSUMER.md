# Gallery Drift — Drift Core consumer 0.1

Git source: https://github.com/riccardopinato/ArtDrift-Infinite-Art-Gallery
Pinned core source commit (candidate only): e9cab00fa20d6fc6087506c84c722d2c8c4fb7d0
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


## G2 cross-app candidate check — 24 November 2026 (exact green ArtDrift head)
This review-only branch temporarily pins ArtDrift Core source `e9cab00fa20d6fc6087506c84c722d2c8c4fb7d0` from ArtDrift [PR #59](https://github.com/riccardopinato/ArtDrift-Infinite-Art-Gallery/pull/59), stacked on integrated [PR #58](https://github.com/riccardopinato/ArtDrift-Infinite-Art-Gallery/pull/58). The current GalleryDrift `main` pin stays **unchanged at 2dac51a6be98ed364d1e95983d1f330c84354ef7**.

Expected parity: optional `museumControls=false` by default and no changes to `InfiniteWorld`, camera persistence, album selection/permissions, search of local photos or photo privacy. This is a consumer compile+tests gate, not a source adoption authorization. Review source changes, `flutter analyze`, `flutter test`, ARM64 Android CI and real Gallery device acceptance before moving pin on main. If ArtDrift PR #59 merges with a new SHA, pin **that exact merged main commit**, do not merge this temporary pre-merge pin as-is.
