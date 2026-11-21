# Synchronization policy — Drift Core

Canonical implementation: ArtDrift-Infinite-Art-Gallery/packages/drift_core.
This application consumes it by an immutable commit SHA. No duplicated gesture,
virtualization or layout implementation belongs in GalleryDrift.

The `drift-core-sync.yml` workflow checks the latest commit modifying that
package on Art Drift's default branch every three hours and on demand; when
the pinned revision differs, a PR is proposed updating only pubspec.yaml and
the source-SHA provenance record. GitHub's Actions setting must allow workflows
to create pull requests; if the setting forbids that, the job fails visibly.
No new secrets are required. Scheduled triggers are not real-time and may lag.

Cross-app change discipline:
1. Shared logic change: implement and test in Drift Core on Art Drift first.
2. Art Drift main green CI + merged SHA is canonical.
3. Gallery pin PR from sync workflow; run Gallery CI + device visual checks.
4. Merge only with evidence; if incompatible, keep old revision and open issue.
5. Gallery-specific media permissions, user albums, privacy & trash stay Gallery owned.
6. A common improvement proposed during a Gallery audit is implemented in the
   canonical core, not cherry-picked into Gallery.

No bidirectional silent file-copy or auto-merge, and no cross-app personal photo sync.
