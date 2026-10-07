# Chippy Local-First Implementation Plan

> Execute inline using superpowers:executing-plans and test-driven-development. The user approved the route and requested execution. No commits, pushes, publishing, or real patient-data calls are part of this work.

**Goal:** Repair existing privacy/data-lifecycle gaps and provide a usable local document workflow with source-backed, reviewable on-device extraction.

**Architecture:** Preserve the cloud backend as a separately selected baseline. Local mode owns protected files, page text, candidate facts, and confirmed corrections on the device. Apple Foundation Models performs bounded extraction; unavailable or refused analysis never uploads data.

**Tech Stack:** Existing SwiftUI/SwiftData/PDFKit/Vision, Foundation Models, FastAPI/LlamaIndex/Chroma/Qdrant. Use Python unittest because pytest is not installed; no new runtime dependencies.

**Spec:** `docs/research/2026-10-06-chippy-direction.md`, approved direction in chat.

## Global Constraints

- Preserve iOS 26.4 and existing unrelated `graphify-out/` artifacts.
- No model downloads, cloud-service mutations, account deletions, or deployment during verification.
- Local import/search/review must work without login or AI availability.
- No implicit upload fallback; cloud processing requires explicit permission.
- AI candidates retain page/source evidence; only confirmed facts enter the reviewed timeline/export.
- New production dependencies require a concrete benefit; none planned.

## Review Focus

- Two users with overlapping documents must never share retrieval results or deletion targets.
- A failed cleanup must retain the metadata needed for a retry; active ingestion must not resurrect deleted vectors within the single-process MVP.
- Multi-page scans and image-only PDFs retain all pages; duplicate filenames never overwrite originals.
- Missing AI, refused analysis, and malformed candidates leave original text usable and send no cloud traffic.
- Historical medication mentions remain historical; guessed dates and values do not become verified facts.

## Checkpoints

### 1. Retrieval and server deletion

Files: `backend/app/ai/query_engine.py`, `vector_store.py`, `pipeline.py`, `api/documents.py`, `api/auth.py`, new `services/document_lifecycle.py`, new `tests/test_privacy.py`.

- [x] Write/run failing unittest regressions using real temporary Chroma, synthetic users, and mocked network boundaries: scoped retrieval, scoped deletion, failed storage cleanup, repeat ingestion cleanup.
- [x] Supply AND tenant/document filters to retrieval and check retrieved metadata before generation.
- [x] Delete Chroma/Qdrant records by mandatory tenant filter; create Qdrant tenant index; production configuration fails closed.
- [x] Share an in-process per-user lock between ingestion and deletion; verify document existence before ingestion; reset old document vectors/events on retry. Document multi-worker limitations.
- [x] Delete storage/vectors before DB metadata; surface cleanup failures; delete all account-owned vectors even orphaned ones.
- [x] Run `backend/.venv/bin/python -m unittest discover -s backend/tests -v`.

### 2. Local protected files and full OCR

Files: new `Services/LocalDocumentFiles.swift`, `DocumentTextProcessor.swift`, modify `DocumentImportViewModel.swift`, `DocumentRepository.swift`, document model, new `ChippyTests/LocalDocumentsTests.swift`.

- [x] Write/run tests for unique same-name imports, scoped cleanup, native-text multi-page PDFs, blank/corrupt inputs, and page ordering.
- [x] Store each document with UUID filename, preserve display filename, and enforce complete protection on files/directories.
- [x] Extract every scan page and every PDF page (native text first, Vision fallback); surface extraction errors.
- [x] Persist page-indexed text locally; allow local import without account/token.
- [x] Centralize local/remote deletion so failures remain visible and metadata is preserved.

### 3. Local-first UI and permission boundary

Files: `RootView.swift`, settings/library/detail/timeline/chat/explainer views, new `Core/ProcessingPreferences.swift`, `Services/DocumentDeletionService.swift`.

- [x] Default to local mode; offer optional cloud sign-in and explicit cloud-data permission. Protect legacy cloud-associated local caches when entering local mode.
- [x] Gate every cloud upload/retry/chat/explanation path; local mode uses local search and reviewed records.
- [x] Show document text by page with original-page preview; expose manual fact entry and correction.
- [x] Make local delete-all clear managed files and models, and preserve cloud-data deletion as an explicit action.
- [x] Correct biometric lock's failure-open behavior and use passcode fallback.

### 4. Bounded local extraction, review, and handoff

Files: new `Services/LocalAnalysisService.swift`, `Persistence/Models/RecordFact.swift`, `Features/DocumentDetail/RecordReviewView.swift`, `Core/ReviewedRecordExport.swift`, tests.

- [x] Test rejection of unsupported evidence, page boundaries, correction state, unknown dates, search, and export exclusion of unconfirmed facts.
- [x] Define app-owned page/candidate types and Apple guided generation; split long pages into bounded segments with fresh sessions.
- [x] Validate verbatim source evidence and each extracted field against it; mark all generated facts unconfirmed.
- [x] Persist reviewed/corrected facts, retain original values, and build a local confirmed-fact timeline and user-selected export.
- [x] Present AI availability/error states and cancellation without switching providers.
- [x] Provide a synthetic evaluation fixture/harness; leave real-device latency/quality assessment explicit.

### 5. Verification and handoff

- [x] Run the whole backend suite, iOS unit tests, unsigned simulator build, and realistic local UI checks.
- [x] Inspect rendered local onboarding/library/review/settings and final diff; request an independent read-only review.
- [x] Update README and only matching todo entries after checks pass. Track remaining model-device and distribution work without marking release complete.

## Commands

```sh
backend/.venv/bin/python -m unittest discover -s backend/tests -v
xcodebuild -project ios/Chippy/Chippy.xcodeproj -scheme Chippy -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,id=83A813CB-A80A-44DC-A2F0-7E566FD9926B' -derivedDataPath /private/tmp/chippy-local-first CODE_SIGNING_ALLOWED=NO test
git diff --check
```

## Self-review and rulings

- Isolation: work on branch `chippy/local-first` in the shared checkout; no parallel implementers or separate checkout needed. Preserve untracked research/graph files.
- Scope: fully offline arbitrary medical reasoning is not claimed. Build bounded extraction and manual verification; physical-device evaluation remains necessary.
- Privacy: cloud mode continues as an explicit alternative; local mode must not mix legacy cloud caches with the local store.
- Tests: use real storage/OCR/SwiftData where possible and synthetic records only. Test network-facing cleanup with a stateful boundary fake.
- Release: App Store Connect, distribution signing, physical-device VoiceOver, and real-model performance cannot be completed by local simulator checks.

## Execution evidence and rulings (2026-10-06)

- Retrieval, vector deletion, orphan storage cleanup, retry cleanup, queued-job deletion, upload/reset interleavings, and failed explanation caching: 18 backend regressions pass using synthetic data.
- Local file/OCR/evidence/persistence/consent/correction/deletion tests: 19 Swift Testing cases pass. Physical-device benchmark explicitly skips on simulator.
- Two simulator UI workflows pass: no-login navigation/cloud-consent cancellation/deletion confirmation, and synthetic photo import/OCR/manual fact review/selected export. Rendered review, settings, and export screens were inspected; no record was actually shared.
- Independent read-only review found four important issues: pending local import resurrection, mutable cloud account identity, upload/reset admission, and signed/comparator numeric evidence. All corrected; their regression coverage is in the test files. Concurrent authentication attempts also now have a guard.
- Ruling: retain the previous unscoped shared cache separately instead of migrating it into local or account stores — ownership cannot be reconstructed reliably. Cost: old local-only originals require recovery/re-import; a separately confirmed cleanup is provided.
- Ruling: keep the backend lifecycle gate single-process for this MVP — a durable queue and deletion state need deployment design/testing. Cost: it cannot protect a multi-worker launch; production cloud remains a release gate.
- Ruling: use literal local search and reviewed fact extraction — arbitrary on-device medical chat is unvalidated. Cost: broader Q&A remains available only through explicit cloud mode or later evaluation.
- Additional regression coverage verifies legacy vector-payload deletion, rejects unsafe storage paths and upload filenames, and preserves blank/image-only PDF pages.
- Fresh evidence: `/private/tmp/chippy-backend-final.log` (18 tests, OK), `/private/tmp/chippy-ios-unit-final.log` (19 Swift tests, TEST SUCCEEDED), `/private/tmp/chippy-validation-final.log` (2 UI tests, zero failures; physical-model benchmark skipped). Simulator builds succeeded; `git diff --check` passed.
- Physical-device model quality/latency, biometric/VoiceOver QA, and release checks remain pending. The paired iPhone was unavailable and running iOS 26.3, below the preserved 26.4 target. Harness completion does not count as model validation.
- No commits, pushes, cloud-service changes, or deployment performed. `graphify-out/` and iOS 26.4 remain untouched.
