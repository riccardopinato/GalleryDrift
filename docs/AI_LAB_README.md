# Gallery Drift AI Lab — isolated Android research build

**Experiment only, DO NOT MERGE as production.**

## Isolation
- From Gallery Drift experimental feature snapshot `2504a1f7e5fc001e0dbce9de49e72834705454cf`.
- Isolated branch `experiment/gallerydrift-mobileclip2-s0-lab-20261122`; base PR `main` for review only.
- Android application ID: `com.riccardopinato.gallerydrift.lab`; displayed name: **Gallery Drift AI Lab**.
- Gallery Drift production application ID remains `com.riccardopinato.gallerydrift`, untouched.
- Gallery, search, trash, favorites and settings work with a completely separate sandbox. There is no import of production app data; photo access still requires Android runtime permission.
- No change to Art Drift, the pinned shared Drift Core, Gallery Drift main or PR #12.

## Important license restriction
Apple's [MobileCLIP2-S0](https://huggingface.co/apple/MobileCLIP2-S0/blob/main/LICENSE)
weights are licensed **apple-amlr, research purposes only**. This license explicitly
EXCLUDES product development and commercial products. A third-party ONNX
export labeled MIT **does not change the upstream weight license**.

Only non-commercial scientific research/evaluation may use the weights under
their terms. Do not ship Apple weights in an APK, publish them in the GitHub
repository, or use them as a commercial component. A shipping Gallery Drift
needs separately licensed weights (e.g., Apache-2.0 alternatives).

## Android experimental feature gate
The following is a staged implementation. An APP build / green CI only proves
compilation and tests, not actual ranking on-device. For acceptance:
1. Confirm both image and text ONNX encoder sessions produce normalized
   **512-dimensional** embeddings for the SAME model family.
2. Compare against a known-good reference Python tokenization + image transform.
3. 100 controlled photographs including 20 cats, compare search hit rate and
   incorrect matches. Report recall@10 and precision@10, not fake probabilities.
4. Index 5,060 selected files to an app-private, revision-keyed store. Do not
   read outside the explicitly selected folders.
5. Profile a real ARM64 Android, battery/thermal/RAM and pause/resume.
6. Keep captioning model OPTIONAL and separate. Captioning outputs generated
   text and can hallucinate; embedding retrieval is not captioning.

## Model manifest (source reference, weights NOT included)
- Source: `felixhrdyn/mobileclip2-s0-onnx`, subject to upstream Apple license.
- Image: `vision_model.onnx` (FP32)
- Text: `text_model_quantized.onnx` (INT8)
- Tokenizer: `tokenizer.json`, CLIP BPE length 77.
- Approximate bundle: 105 MB models + 2.1 MB tokenizer.
- Image preprocessing: 256x256, bilinear center crop, OpenAI CLIP RGB
  mean/std [0.48145466,0.4578275,0.40821073] /
  [0.26862954,0.26130258,0.27577711].
- Outputs: L2-normalized vectors length 512; cosine ranking.

**No claim of real on-device success until an artifact has been executed and
benchmarked on physical hardware.**
