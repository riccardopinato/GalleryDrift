# Gallery Drift — shared Auto canvas and prefetch adoption

Core provider: ArtDrift `packages/drift_core`
Pinned source: `56af2a4b9f6f44a00b3197eda4bc217b5adfea39`

## Shared controls
- Auto vertically explores the canvas; manual pan/pinch pauses.
- The speed button cycles 25→50→75→100→25%, persistently scoped
  to the Gallery camera (All Photos vs Favorites).
- Both buttons sit directly under the upper-left brand and fade after 3s.

## Gallery-only adapter
- Warm 420x420 PhotoManager thumbnails in advance using the exact same
  Future that on-screen LocalPhoto consumes. No full-resolution preloading.
- Bounded JPEG-byte LRU: 12 MiB, 90 entries, 4 concurrent native thumbnail
  requests; max 28 speculative queued requests. Visible tiles jump the queue.
- Evict deleted assets; clear loaded and queued private thumbnails when album
  selection changes. On-disk native cache behavior remains under PhotoManager.
- No upload or sync, no extra photo permissions and no changes to deletion.

## Evidence
Flutter analyze/test/build on Gallery exact SHA; Art Core tests and Flutter
Web/Android on the canonical Art commit. Actual FPS, battery use, memory
and missing-image incidence require Android device validation.
