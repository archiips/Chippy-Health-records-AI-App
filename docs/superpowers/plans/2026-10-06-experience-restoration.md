# Chippy experience restoration

## Outcome and constraints
Restore the app's document/timeline/chat experience within the approved local-first route. User reports that chat disappeared, timeline feels like a notes app, and clean PDFs do not represent camera imports. Preserve existing records, iOS 26.4, explicit cloud consent, and uncommitted work. No patient records, deployment, dependencies, or automatic data migration.

## Chosen design
- Four primary tabs: Records, Timeline, Chat, Settings; page search remains accessible in Records. Reuse the existing lavender identity, system typography, adaptive backgrounds, meaningful category icons, and native controls.
- Records: original thumbnails, meaningful rename/type editing, type filter and sorting, inline search, prominent camera/photo import. Photos/scans remain image-origin documents even though their protected multi-page container is a PDF.
- Timeline: month/day grouping, category and time filters, a connecting chronology rail, event cards grouping facts from the same source/date/category. Undated facts never borrow upload dates. Pending review is a separate queue. Lab values include ranges; dated comparable confirmed values can chart without diagnosing.
- Chat: persistent local conversation and scope selection; useful medication/lab/latest/overview questions plus free-text lookup; clickable page citations. Apple Foundation Models may translate a query into a bounded search plan; answers are assembled from copied record fields/excerpts. Simulator/model unavailable uses deterministic lookup; no silent cloud fallback. Cloud chat remains in explicitly selected cloud mode.
- Photo fixtures: clearly fictional camera-style medical paper, with perspective/shadow and realistic table layout, plus OCR regression and photo-picker end-to-end test. These validate import behavior, not clinical AI accuracy.

## Alternatives and critique
Merely re-exposing cloud chat would break no-login/local behavior; unconstrained local medical reasoning is not validated. Keep source-driven answers and be explicit about limits. A separate Search tab crowds navigation; keep search in Records. Grouping all facts by upload date would look populated but misrepresent chronology. Never infer abnormality/current medication use from missing context. Preserve quote review and original-page navigation. Check Dynamic Type, dark mode, VoiceOver labels, and cancellation/reset invalidation.

## Checkpoints and acceptance
1. Add regressions for timeline grouping/unknown dates, question lookup/citations, and photo OCR. Confirm failing tests before implementation.
2. Implement source-driven chat, source scope, persistence/clear/reset, category/date timeline and lab trends. No upload in local workflows.
3. Restore library thumbnails/search/filter/sort and record presentation/classification controls.
4. Run iOS unit/UI tests on synthetic photo inputs, inspect rendered Records/Timeline/Chat/Review in light and dark, run diff check. Record limits and exact results.

## Validation
`xcodebuild -project ios/Chippy/Chippy.xcodeproj -scheme Chippy -destination 'platform=iOS Simulator,id=83A813CB-A80A-44DC-A2F0-7E566FD9926B' -derivedDataPath /private/tmp/chippy-local-first -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test`

Apple sources checked 2026-10-06: https://developer.apple.com/documentation/vision/recognizing-text-in-images and https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models . Vision recognizes image text; Foundation Models supports guided generation and app-owned retrieval. Neither establishes medical correctness. Real-device AI/camera/biometric QA remains pending.

## Verified checkpoint — 2026-10-06
- Backend: `backend/.venv/bin/python -m unittest discover -s backend/tests -v` — 18 passed; checkpoint committed/pushed as `3ec3e2d`.
- iOS: validation command above with fresh `/private/tmp/chippy-restored-verification` derived data and `-only-testing:ChippyTests` — 32 Swift Testing tests passed; one physical-model XCTest intentionally skipped on simulator. Actual Vision OCR checked both camera-style fixtures and the unmodified public provider sample (see fixture provenance). A fragmented diagonal watermark is not required; checked lab names, values, units and a reference range are.
- UI: same destination/derived data with `TEST_RUNNER_CHIPPY_SYNTHETIC_PHOTO=1` and `-only-testing:ChippyUITests/ChippyUITests` — all three passed: navigation/consent cancellation, library filters, and photo import → manual review → dated timeline/chart → chat source → export preview. No document was shared or uploaded.
- Rendered screenshots inspected for Records, Timeline, source review, Chat and export. Existing forced-dark appearance is retained; a separate light-mode and real VoiceOver/Dynamic Type pass was not established. `git diff --check` passed.
- Independent read-only review completed. Corrected all four findings: named-test filtering before latest-date selection, chat cancellation separate from import lifecycle, normalized-date event grouping, and exclusion of unknown-unit lab comparisons. Added corresponding regressions.
- Remaining release gates: compatible-device Foundation Models query/extraction evaluation, real camera and biometrics, historic installed-store migration checks, accessibility and large-library performance, production cloud infrastructure. Legacy shared cache remains deliberately separate/manual-reimport because ownership was not retained. These are not claimed complete.

### Chat usability correction
User reported that the open simulator chat did not work. Inspection showed repeated OCR passages; seven new regressions failed for common wording, help, follow-ups, duplicate OCR, clinical-context wording and Stop state. Implemented and verified corrections; persistent scope/help/quick questions and expandable extra sources improve discoverability. UI checks now identify the newest assistant message rather than accepting an older matching answer.

Fresh verification: `xcodebuild` at the destination/derived-data path above, `-only-testing:ChippyTests -only-testing:ChippyUITests/ChippyUITests`, with the seeded photo opt-in — 39 Swift tests and 4 UI tests passed; physical AI benchmark skipped. After screenshot inspection, compact source cards were added and the four UI tests passed again; final screenshot inspected. `git diff --check` passed. Native computer-control actions could not target the simulator window; real app interactions were exercised through XCTest instead. Full conversational local AI is still not implemented; the screen and README describe source lookup explicitly. Apple Foundation Models availability and safety documentation checked 2026-10-06; existing on-device search-term assistance and guardrails remain unchanged.
