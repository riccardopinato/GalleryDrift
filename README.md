# Gallery Drift

Gallery Drift explores **only user-selected local folders** on an infinite
two-dimensional mosaic. Photo and video thumbnails are read on demand;
original images are not copied to the app library, cloud or GitHub.

The canvas engine is pinned from the sister project
[Art Drift](https://github.com/riccardopinato/ArtDrift-Infinite-Art-Gallery).
Folder permissions, MediaStore indexing, favorites, search, backup and trash
are Gallery-only adapters.

## Current development status

- Main: v0.3.3, Android ARM64 signed/release CI documented separately.
- [GD-01–10 reliability and media PR](https://github.com/riccardopinato/GalleryDrift/pull/12):
  proposed source changes only while the PR is draft. Read the exact-head CI
  and physical QA gates before describing a feature as delivered.
- Backup contains selected folder IDs, favorite IDs, locale and camera position
  **only**. It does not copy photos/videos or grant Android permissions.
- Delete and batch trash use Android's own MediaStore approval, not direct
  filesystem manipulation. App state changes only for confirmed successful IDs.
- Visual recognition uses local ML Kit labels, not open vocabulary similarity
  or face identity recognition; video searches use filenames/album metadata.

Do not install a new APK over a signed release unless the package ID, signing
certificate and increasing versionCode have been verified. Physical device
acceptance and Play Store compliance remain separate from green CI.

See [GD-01–10 audit and verification matrix](docs/GD_01_10_REMEDIATION.md).
