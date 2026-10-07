# Chippy — Your Health History, Finally Clear

Chippy is an iOS record organizer that starts on your device, without login. Import a PDF, scan, or photo; search page text; compare facts with the original; and share selected reviewed facts for an appointment.

## Current local workflow

- Import preserves every page. PDFs use native text when available and Vision OCR otherwise; scans OCR every image.
- Originals have unique protected filenames. Local files and SwiftData stores use complete device file protection, are excluded from backup, and disable CloudKit.
- Apple Foundation Models suggests bounded, source-quoted facts when the model is available. Missing models, unsupported languages, refusals, and failed evidence checks do not trigger an upload. Manual review remains available.
- Suggested facts stay unconfirmed. Review or correct each fact against its original page before confirming it. Initial values and evidence are retained after correction.
- Only confirmed facts enter the local timeline or selected export. Unknown dates are never replaced with today; historical medication mentions do not establish current use.
- Records includes original thumbnails, search, document-type filters, sorting, and editable names/types. Camera and photo imports are prominent; a protected PDF container preserves the original photo pages.
- Timeline groups reviewed facts into dated medical events with category/date filters, a chronology rail, a separate review queue, and recorded-unit lab charts. Explicit written dates are normalized when unambiguous; ambiguous dates stay separate.
- Chat is a primary tab again. It supports medication mentions, latest labs, reviewed summaries, and free-text record lookup, with persistent history, record selection, and clickable page citations. On compatible hardware Apple Foundation Models can expand search terms; replies copy stored fields/passages. Simulator or unavailable-model lookup remains useful without uploads. Free-form medical reasoning, diagnosis, and treatment advice remain outside this milestone.
- Chat recognizes common result/summary wording, greets and guides users, and reuses the prior topic for simple follow-ups. Suggested questions and record selection stay visible; OCR excerpts are short and duplicate passages are suppressed. Extra source cards expand on demand. “How Chat Works” explicitly describes the available mode.

The deployment target remains **iOS 26.4**. Foundation Models additionally requires compatible Apple Intelligence hardware, enabled Apple Intelligence, a downloaded model, and supported device language. Simulator success does not establish model accuracy or latency.

## Optional cloud baseline

Settings → Use Cloud Mode presents an explicit data permission screen before sign-in. New cloud imports send originals and OCR text to the development backend, which uses Gemini extraction/chat, Supabase, and Chroma or Qdrant. Local records are never transferred automatically. Launching the app again starts in local mode; cloud permission is session-scoped. Return to local mode from cloud Settings or the sign-in toolbar.

Each cloud account has its own protected local cache. Switching accounts invalidates outstanding import/refresh work. Previously uploaded records can sync from the server and originals can be retrieved using signed URLs.

The previous build’s shared cache is **not automatically migrated or mixed into either mode** because it did not retain reliable local ownership. Keep copies of old originals, recover server records by explicitly signing in, or re-import your originals into local mode. Local Settings offers a separately confirmed removal of that old cache; new local and per-account cloud records are preserved.

Backend retrieval applies both owner and selected-document filters. Deletion removes owned files and vectors before metadata, reports retryable cleanup failures, and sweeps orphaned storage/vector data during delete-all. Uploads, ingestion, and cleanup coordinate in a single-process lifecycle gate. This gate is **not a distributed queue or multi-worker guarantee**; a durable job system and deletion state are still required before deployment with real users.

The cloud path remains a development baseline using a localhost server URL. Custom JWT refresh tokens are currently stateless and are not revoked or single-use. Cloud delete-all removes stored records/chats, while the Supabase login identity remains; full account deletion is still release work. Do not treat this build as production-ready or HIPAA-certified. Provider settings, server privacy controls, deployed RLS, and distribution checks remain release work.

## Build and checks

Open `ios/Chippy/Chippy.xcodeproj` in Xcode 26.4. Run on a device with a passcode for the default device-authentication lock. Scanning requires a physical device.

```sh
backend/.venv/bin/python -m unittest discover -s backend/tests -v
xcodebuild -project ios/Chippy/Chippy.xcodeproj -scheme Chippy -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test -only-testing:ChippyTests -only-testing:ChippyUITests/ChippyUITests/testLocalWorkflowWithoutLoginAndCloudConsentCanBeCancelled
git diff --check
```

Backend tests use synthetic users, a real temporary Chroma store and in-memory Qdrant, and fake network/storage boundaries. iOS tests exercise real files, PDF/OCR, SwiftData cascades, evidence checks, and reviewed export. The UI test disables the lock only through standard launch preferences in its simulator session.

`LocalModelEvaluationTests.testSyntheticDeviceBenchmark` skips on simulator or when the model is unavailable. Run it on compatible hardware; its retained Xcode JSON attachment records elapsed time, grounded candidates, and expected-fact coverage. It is a small synthetic smoke benchmark, not clinical validation. Expand evaluation to diverse synthetic/redacted records and measure omissions, incorrect associations, OCR errors, refusal rate, latency, and memory before deciding whether another model is needed.

Research and decisions: [direction](docs/research/2026-10-06-chippy-direction.md), [implementation plan](docs/superpowers/plans/2026-10-06-local-first.md).

## Informational use

OCR and AI can make mistakes. Chippy does not establish a diagnosis, treatment, or current medication list. Review originals and consult a qualified healthcare professional.

### Optional synthetic photo UI check

Use a dedicated simulator. The photographed medical fixtures in `ios/Chippy/ChippyTests/Fixtures/` are clearly fictional camera-style lab and medication documents with skew, shadows, and tables. The same fixture folder includes an unmodified public provider sample report for OCR checks, with provenance in its README. Seed the fictional lab image last; the opt-in UI test chooses the most recent photo. Replace `DEVICE_ID` below with the dedicated simulator’s identifier:

```sh
xcrun simctl addmedia DEVICE_ID ios/Chippy/ChippyTests/Fixtures/photographed-lab.png
TEST_RUNNER_CHIPPY_SYNTHETIC_PHOTO=1 xcodebuild -project ios/Chippy/Chippy.xcodeproj -scheme Chippy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test -only-testing:ChippyUITests/ChippyUITests/testSyntheticPhotoReviewAndExport
```

This opt-in test selects the most recent photo, so only run it after seeding the synthetic fixture. It imports a photographed lab document, confirms a manually checked fact, opens the dated timeline and lab chart, asks a local chat question, follows its source page, and inspects export without sharing it. These fictional photos are not clinical validation; real-device camera/model/accessibility QA remains pending.
