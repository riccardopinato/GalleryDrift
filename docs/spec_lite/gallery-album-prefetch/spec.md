# Gallery Drift — bounded album-next-page warmup (Spec Lite FAST pilot)

**ID:** `FSL-20261127-GALLERY-PREFETCH` · **Source baseline:** `dde42c11d96ee6258670b01ce9e7b3c273cc56ab` · **Factory:** `f8b9f550c544735237f19cdd723bd2df667ceee6`

**Status:** implementation requested as part of the user's sequential Spec Kit pilot roadmap. This manifest remains `PROPOSED / NOT_VERIFIED` until a separately anchored canonical product/roadmap authority and trusted evidence are available. Not a Play/device acceptance claim.

## Feature and ownership

Gallery-only (local album pager), not Drift Core and not Art Drift. Gallery keeps device photos private; no upload, no new permission, no MediaStore write, no new dependency. Inspect Gallery and Art main SHA plus relevant open Core PR before code.

## FR-001

Warm only one next album page when a user approaches a page boundary, sharing the foreground cached Future and preserving album selection, privacy, and normal read retries.

- **AC-001:** At pageSize four, reaching index two causes exactly one range read for the next page, and index five reuses the warmed cache.
- **AC-002:** Negative, empty, past-end, and final-page cases do not read outside the selected album or trigger unnecessary range queries.
- **AC-003:** A failed MediaStore background prefetch is evicted and permits a fresh foreground retry with the correct resulting image.

## Exclusions

No canvas math, visual style, shared Core, trash/keep behavior, cloud, purchases, photo selection or Gallery ThumbnailCache logic.
