# Gallery Drift — Drift Core consumer 0.1

Git source: https://github.com/riccardopinato/ArtDrift-Infinite-Art-Gallery
Pinned core source commit: dbf2fc0260ed3cbea822c138114122b98e5e810d
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


## Temporary G2 consumer QA — 23 November 2026

**TEST-ONLY PIN:** `dbf2fc0260ed3cbea822c138114122b98e5e810d` points at the unmerged Art Drift G2
integrated candidate PR #40. It is NOT a production or main-branch upgrade.
This draft branch exists only to run Gallery Drift's Flutter analyzer, widget
tests, ABI/size policy and internal Android build against the optional new
Drift Core museum controls and tile anchors. The default Gallery behavior
must remain unchanged. Keep this test branch separate and DO NOT merge or
update Gallery Drift main unless Art Drift's Core has first passed the
canonical source gates and an explicit user-approved consumer update.
