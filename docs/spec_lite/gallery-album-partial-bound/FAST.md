# FAST compact pilot — Gallery Drift album prefetch bound

Origin: App Factory Core `a185c16000608b90c5db639f37903b49b059b10b` (Master v27, Spec Lite selective); source pin `c7f0f51c764b48228e803e3a64e2d4f9e971beae`. This is a low-risk Gallery-only behavior fix, not a Shared Drift Core modification.

## Delta · MODIFIED
Old: prefetchNext warms the next page through at(nextStart), whose range reader always asks for a full page even when the album's last page has fewer items.
New: when totalCount is known, prefetchNext requests only up to the exclusive `totalCount`; the same Future is reused by foreground at(index). No media files, trash, permissions, model or shared canvas changes.

## Plan / task
Update only `lib/services/album_pager.dart` and `test/album_pager_test.dart`. Add regression for `pageSize=4`, `totalCount=9`, expected range `8:9` and cached foreground read. Preserve existing prefetch and retry tests.

## Acceptance / evidence
FR-001 / AC-001: next partial page stays in selected album bounds (UNIT_TEST).
FR-001 / AC-002: foreground at(8) reuses the bounded Future with no second range read (UNIT_TEST).
FR-001 / AC-003: all existing album pager tests remain green (UNIT_TEST).

Initial status: `PROPOSED`; this document does not approve product scope, certify runtime/device, or replace GitHub/AppLab CI. No separate spec/plan/tasks/evidence ledger, per FAST lean decision. Read PR source diff, exact-head CI and any required device QA before final product adoption.

## Integration receipt (source scope)

PR [#20](https://github.com/riccardopinato/GalleryDrift/pull/20) merged to `30c26f2b23bccbf9237163467ef0fe664e915967`. Branch Android CI passed, including added regression. Postmerge Android [run SUCCESS](https://github.com/riccardopinato/GalleryDrift/actions/runs/45984531353) on main `30c26f2b23bccbf9237163467ef0fe664e915967`; source/CI verified, NOT device or store certified. Scope remains Gallery-only and runtime/device acceptance remains NOT_VERIFIED.
