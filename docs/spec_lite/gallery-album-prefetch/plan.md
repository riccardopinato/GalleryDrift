# Plan — bounded Gallery-only warmup

Baseline source `dde42c11d96ee6258670b01ce9e7b3c273cc56ab`, dependency Drift Core pinned to `2dac51a6be98ed364d1e95983d1f330c84354ef7` in Gallery `pubspec.yaml`. Canonical Art main `72e00e726abbd8ffb2806ef3cc3220d46fd7a501`. Shared Core PRs #59/#85 remain distinct and untouched.

1. Reuse existing `AlbumPager.at` and `_pages` cache; do not introduce queue, new downloader or mutable storage.
2. Add `prefetchNext(index,totalCount)` to `lib/services/album_pager.dart`, activate only on last two indices of a page and never past totalCount.
3. Invoke asynchronously only from `PhotoDetail._activate`, ignore prefetch errors because the existing foreground access provides explicit retry; preserve page interaction responsiveness.
4. Extend `test/album_pager_test.dart` with cache reuse, end-of-album/no-op and transient error recovery tests. CI: Flutter analyze, tests, Android debug build if repository workflow requires.
5. Rollback: revert this narrow PR; no migration or persistent data change. Keep prefetch separate from private thumbnail cache.

No new runtime permissions, paid provider, new PR in Art, or product release.
