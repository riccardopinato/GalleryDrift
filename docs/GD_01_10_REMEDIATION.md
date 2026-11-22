# Gallery Drift — GD-01–10 remediation and verification

Baseline App Factory: App-Factory-Core@ede07c491e586215598ff68daec43e17d699aa51,
Master v27, Golden Index v31. App target main:
GalleryDrift@7c270e4762a22c262047d0d2048aa6542e724d68.
Canonical sibling:
ArtDrift-Infinite-Art-Gallery@586b3009308d7b09883f63a4dd80cdae208712c5.
Drift Core remains pinned and unchanged in the Gallery consumer.

**State of this document: 0.3.4+8 implementation PR, NOT device-certified
and NOT Play-ready.** Every check below needs exact-head CI proof before merge.
The MediaStore scan enumerates full folder metadata because change events do
not reliably identify altered assets; only changed/removed IDs invalidate
local image caches and derived visual labels. This is incremental reconciliation,
not a falsely claimed platform-level delta query.

| ID | Owner | Intervention | Mandatory evidence |
|---|---|---|---|
| GD-01 P0 | GALLERY_ONLY | bounded MediaStore pagination through full album; dedup with first-selected folder | 2,001-photo test, physical album of >800 and >10,000 |
| GD-02 P0 | GALLERY_ONLY | native MediaStore observation, debounce refresh and scan cancellation | add/modify/rename/remove on Android, background/resume, 10k media |
| GD-03 P0 | GALLERY_ONLY | explicit Android scoped/limited permissions and OS-confirmed trash | Android 10/13/14/15/16, deny/limited/partial/revoke, recover from system trash |
| GD-04 P1 | GALLERY_ONLY | source original-file zoom and resolution-tier decoding | 12/48MP, HEIC rotated/EXIF, low-RAM pinch 1x–5x |
| GD-05 P1 | GALLERY_ONLY | full selected catalog lexical + optional foreground image labels | target image at index 1,501, cancel/resume, 5k-asset CPU/battery |
| GD-06 P1 | GALLERY_ONLY | stop page swipes when observed folder changes; refresh after viewer closes | delete/move photo before/after current index mid-swipe |
| GD-07 P1 | GALLERY_ONLY | SHA-256 validated, versioned preferences JSON (no media) + inspect/confirm/rollback | fresh install, backup restore and existing-device upgrades |
| GD-08 P2 | GALLERY_ONLY | local video thumbnail/playback/scrubbing | short/long, unsupported codecs, permission denied, 4k playback |
| GD-09 P2 | GALLERY_ONLY | multi-select and bounded OS-mediated trash batches | confirm/cancel/partial successes, no silent deletion |
| GD-10 P2 | GALLERY_ONLY | product-owned dark photo-led design tokens and subtle glass shell | screenshot comparison, contrast, large font, 360dp, reduce motion |

## Design provenance

Reference: `Design-App/BIBLIOTECA_COMPONENTI/sorgenti/ruixen/glass-image-editor.tsx`
and `image-card-fan.tsx`, **ADATTATA** as lightweight cinematic
surface layering and content-led density only. Do not copy TSX/CSS/assets.
The radial fan is **NON ADATTA** for main canvas because it interrupts
pan/zoom/fling virtualization and may hinder accessibility. Photos remain
native user media and are never uploaded for preview.

## Device acceptance matrix

1. Fresh install, grant and deny; selected folder with >10,000 photos,
   verify complete count and stable canvas pan/zoom, memory, and no jank.
2. Android 14+ selected/limited photo access, expand/revoke while open;
   verify selected-folder privacy, visible correction, and error recovery.
3. Create, edit, move, trash and restore images via other apps while
   Gallery Drift is backgrounded, foregrounded and viewing an album.
4. Move to Android trash: user denies, authorizes, partial batch, restores
   from system Gallery; app must never claim deletion without OS confirmation.
5. Backup preferences, clear app state, restore, relaunch, compare
   albums/favorites/language/camera; checksum corruption must reject.
6. Large photos: original resolution and orientation, pinch 1x–5x
   without OOM. Video: seek/pause/resume/leave foreground.
7. Confirm signing certificate, package name and increasing versionCode
   before any update over installed data. No forced uninstall to upgrade.
8. AppLab screenshot/semantics/perf tests; QA signoff on physical Xiaomi,
   Pixel, and Samsung profiles where available.

## Explicit exclusions

No network upload of personal images; no system-wide file access
`MANAGE_EXTERNAL_STORAGE`; no free-form face recognition, AI cloud
processing, billing, ads, or external trash implementation.
