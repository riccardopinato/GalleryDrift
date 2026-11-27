# Tasks and acceptance mapping — Gallery pilot

- [x] T001 — Reconcile Gallery/Art main, Drift Core pin, open shared-core PRs; feature classified GALLERY_ONLY.
- [x] T002 — Implement bounded `AlbumPager.prefetchNext` without new page/cache authority (FR-001).
- [x] T003 — Wire non-blocking album viewer warmup; keep failed reads retriable (FR-001).
- [x] T004 — Add direct unit regressions: AC-001, AC-002, AC-003 (source written, CI pending).
- [ ] T005 — Obtain exact-head Flutter analyzer/test/build CI evidence; record link in an external pilot evidence ledger.
- [ ] T006 — Review user interaction/physical device latency only if separately available; never infer from source tests.

The checkmarks describe code edits, not test or runtime certification. All three AC rows remain NOT_VERIFIED until GitHub CI evaluates this PR head.
