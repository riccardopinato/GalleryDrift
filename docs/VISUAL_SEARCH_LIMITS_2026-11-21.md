# Gallery Drift 0.3 — Search v1: on-device visual labels + metadata

STATUS: SOURCE IMPLEMENTED; Android CI and device accuracy to be separately verified.

- Search currently uses filename + album name for every accessible selected photo, without any indexing step.
- User taps **Analyze photos** to launch on-device ML Kit labeling over ONLY the current selected-album canvas bootstrap (at most 800 files/album).
- Analyzes scaled thumbnails, stores only device-local asset id / modification revision / English labels (no image bytes) in app-support JSON. Temporary image is deleted after each call. Cancel and Clear Index available.
- Search merges partial filename/folder matches and labels; common synonyms translated from six UI languages to English.
- No app-owned upload of photo content; ML Kit on-device processes pixels, but SDK may collect device/app/performance diagnostics requiring Play Data Safety disclosures.
- Label model fixed ~400 general categories; DOES NOT guarantee open-vocabulary language-to-image matching, exact cities, architectural landmarks, exact people or individual identity, copyrighted characters, pets by name or all imaginable objects. A negative result can be false negative.
- For arbitrary text (New York, Paris, personal names) reliable results are currently only from album / filenames unless the classifier itself outputs a suitable label. Full CLIP-style multilingual embedding retrieval is a separate optional capability with downloadable model, privacy/accuracy and size gates.
- Re-index when photos change. Cache is invalidated by AssetEntity.modifiedDateTime and modelVersion, limited to the current selected photo IDs when scan starts; delete resets a particular record.
- Search index may consume battery/CPU/storage. Foreground explicit processing only, progress and stop.
- The visual index is independent from Drift Core and Art Drift, which remain unchanged.
- Follow-up: complete album discovery beyond 800, exact retrieval quality benchmark, model download licensing, UMP/Play SDK disclosure updates before store publication.
