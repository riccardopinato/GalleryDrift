# Gallery Drift — Drift Core consumer 0.1

Git source: https://github.com/riccardopinato/ArtDrift-Infinite-Art-Gallery
Pinned core source commit: f9e35e0a11f76bf93992b4527aab42191b4ac545
Package path: packages/drift_core
Consumer repo: riccardopinato/GalleryDrift

## Contract
The gallery NEVER copies Art Drift canvas code: it imports drift_core and supplies local AssetEntity tileBuilder, album list and gallerydrift.* camera/prefs namespaces. Shared canvas changes occur in Art Drift core package first; Gallery updates only the immutable dependency ref after passing CI.

## Early implementation boundaries
- Start with **zero selected albums**; no read request on first launch.
- Request photo permission from Settings explicitly, then show only the selected albums.
- Android plugin: photo_manager ^3.12.0 (Apache-2.0), platform MediaStore (photo_manager).
- Initial indexing is bounded to 800 media objects per selected album; complete pagination, background catalog and live changes must be implemented before declaring full-gallery functionality.
- Images only in this first integration. Video playback, sophisticated search/visual Lens, ads, purchases and full privacy-policy publication are not implemented.
- Favorites are app-local and not Android system favorites.
- Trash uses Android 11+ MediaStore trash via plugin and system permission confirmation. Older unsupported Android versions fail closed rather than permanently delete media.
- Play Store media access policy must be reviewed: broad READ_MEDIA_IMAGES is defensible only for sustained photo-gallery core functionality; Data Safety / hosted privacy policy not certified.

No source tests or physical QA are declared passed until GitHub CI evidence exists. This scaffold is a consumer integration, not a Store-ready release.
