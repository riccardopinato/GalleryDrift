# Drift twins — contributor / agent contract

These two independent Flutter products are **paired consumers of one shared engine**:
- Canonical Drift Core: `riccardopinato/ArtDrift-Infinite-Art-Gallery/packages/drift_core`.
- Art Drift consumer: `riccardopinato/ArtDrift-Infinite-Art-Gallery`.
- Gallery Drift consumer: `riccardopinato/GalleryDrift`.

## Mandatory cross-app audit and implementation policy
When asked for an audit, development, UX improvement, bug fix or roadmap for either app:
1. Inspect the current main SHA and version/pin of Drift Core in **both** repositories, plus open PRs affecting common behavior. Do not infer state from chat memory or outdated snapshots.
2. Classify each issue as SHARED_CORE, ART_ONLY, GALLERY_ONLY, or REQUIRES_PRODUCT_DECISION.
3. For SHARED_CORE: develop a single implementation in the canonical core. Verify original Art canvas experience and propagate to Gallery through a pinned SHA PR. Never maintain divergent copies of canvas math/gestures/viewport.
4. Preserve Art Drift's approved visual baseline: mosaics, pinch/pan/fling, UI colors/layout, artwork previews, camera persistence, title/description, search flow. Visual changes require deliberate scope and device QA, not assumption from green CI.
5. Keep local photo library access, album selection, safe trash, metadata and private asset identifiers **Gallery-only**. Do not upload or synchronize device photos to Art Drift or to GitHub.
6. Keep museum APIs, public-domain provenance, art catalog and artist/museum search **Art-only**.
7. Shared header contracts: search control, favorites heart and settings gear (not a tune/sliders icon). Preserve each app's intentional content-specific search/filter behavior and deliberate visual customization.
8. Settings own language preference (it/en/fr/es/de/pt), localized technical/privacy text, app version/info and Play Store required disclosures. In-app privacy summary is not a substitute for hosted policy or accurate Data Safety forms.
9. Advertising is **not enabled by this contract**. Evaluate AdMob placement, consent and Pro entitlements independently with policy and store evidence.
10. Always distinguish SOURCE_IMPLEMENTED, CI_GREEN, VISUAL_APPROVED, PHYSICAL_ACCEPTED and PLAY_READY. Never imply that a PR, CI run or internal APK proves Play compliance.
11. Never silently merge or update both app repos without exact-head CI and Master/Golden gates. Safe automation may open candidate dependency PRs only.
12. Before app development resolve App Factory Core CURRENT.yaml and relevant Master/Golden once per session, without overriding current repository evidence.

This file records product intent, not certification or user photo data.
