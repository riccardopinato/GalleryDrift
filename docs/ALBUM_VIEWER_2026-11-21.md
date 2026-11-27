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

## Final partial-page prefetch — OpenSpec FAST pilot (2026-11-27)

Source change: [Gallery Drift PR #20](https://github.com/riccardopinato/GalleryDrift/pull/20), main `30c26f2b23bccbf9237163467ef0fe664e915967`. For selected album count 9 and pageSize 4, `prefetchNext(7,totalCount:9)` now asks for `getAssetListRange(8,9)` (exclusive end), not `getAssetListRange(8,12)`. The subsequent foreground `at(8)` reuses the bounded Future; transient failures still allow retry. Zero media file writes, no shared Art Drift Core changes, no permission or data retention changes.

Tests: existing `album_pager_test.dart` suite plus one final-page range/reuse regression; branch Android analyze/test/APK CI passed. [Postmerge Android CI](https://github.com/riccardopinato/GalleryDrift/actions/runs/45984531353) initially PENDING at documentation preparation; update this record only after actual SUCCESS. No physical device, album ordering across OEMs, runtime FPS, Play or signed upgrade certification follows from source/CI.
