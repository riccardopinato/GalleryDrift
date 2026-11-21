# Album-scoped swipe viewer — Gallery Drift 0.2.0

Product input: tap any photo in the random infinite canvas, then swipe horizontally through the **actual album** containing that photo (e.g. cousin's graduation); do not swipe in random mosaic order and do not mix selected albums.

Source selection:
- During initial selected-folder indexing, record `AssetEntity.id -> (AssetPathEntity, exact album index)`.
- For an image visible in multiple selected albums, the first selected path returned by MediaStore wins for that session; there is no misleading cross-folder swipe.
- Taps from the canvas, favorites filter and local filename search all resolve the same album scope.
- The selected albums must first be chosen by the user. No new permission, network request or telemetry.

Viewer:
- `PageView.builder` with initial index at the exact tapped photo.
- `AssetPathEntity.assetCountAsync` provides the entire folder count.
- Lazy `getAssetListRange(start,end)` reads 64 photos at a time, with bounded nearby-page cache, so browsing continues past the canvas 800-photo bootstrap limit.
- Individual photo preserves `BoxFit.contain` display (no crop), favorite status and safe Android trash confirmation.
- Show folder name, numeric position, date/size and subtle swipe hint; translations in six existing locales.
- After trash, close viewer and remove the deleted image from the canvas and app-local favorites, rather than risking incorrect shifting MediaStore indices during an open page session.

Scope limits:
- Full album browsing works for a photo initially reachable from the canvas. Canvas discovery is still limited to 800 assets per selected album until separately paginated.
- This version is photo-only (video remains a later milestone), and original image byte zoom is not implemented by this scoped feature.
- Gallery Drift only. Art Drift remains unchanged while its artwork PR is active.
- Device gestures, scoped permissions, album sorting consistency and upgrade signing require physical validation; CI does not certify Play Store readiness.
