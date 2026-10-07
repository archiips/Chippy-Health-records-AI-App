# Chippy: product direction, local AI, and confirmed repairs

Research checked: 2026-10-06. Status: recommendation and proposed scope; no production-code changes or model migration made. This supersedes neither the current architecture nor the existing task list until the direction is selected.

## Outcome and assumptions

The user requested repairs to the identified gaps, a current competitive assessment, and an assessment of replacing Gemini with on-device AI. Preserve the current iOS 26.4 deployment target. The original project instructions explicitly put LLMs and embeddings on the server; local inference is a proposed architecture change, not an existing implementation commitment.

Working assumption: Chippy is intended for eventual public release to people organizing their own records. A personal-only tool would make offline ownership a sufficient objective; a commercial product needs evidence that a specific workflow is underserved. Purpose clarification and approval of the concrete repair scope are pending.

Recommendation: repair the existing data-isolation, deletion, and import paths first. Develop Chippy toward a local-first, source-verifiable record organizer for people with documents from several providers. Evaluate Apple Foundation Models for bounded extraction and rewriting before migrating inference. Do not make unrestricted medical chat or a particular model the product's central promise.

## Competitive baseline

These are provider descriptions, not independent evaluations of accuracy, traction, or user satisfaction. All links were checked on the research date. Absence of a feature from a marketing page is not evidence that a competitor lacks it.

| Alternative | Published capabilities | Implication for Chippy |
| --- | --- | --- |
| [Guava](https://guavahealth.com/faq) | Portal/PDF/photo records, extracted health information, tracking, printable visit preparation, and sharing. Its [visit-prep page](https://guavahealth.com/prepare-for-visits) describes the established appointment workflow. | Import, timeline, and appointment summaries already overlap. |
| [ChatGPT Health](https://openai.com/index/introducing-chatgpt-health/) | Connected medical records and wellness apps, contextual explanations and appointment preparation; dedicated privacy controls and no foundation-model training on Health conversations. | General health Q&A and a generic privacy promise are weak differentiators. Availability is not inferred from its launch announcement. |
| [Citizen Health](https://www.citizen.health/) | Record-grounded answers, appointment preparation, medication history, and an advocate for complex-care administrative tasks. | A broad caregiver/rare-disease assistant would compete with a much wider service. |
| [PicnicHealth](https://picnichealth.com/) | Consolidated medical history and support for understanding the next steps in care. | Record aggregation alone is established. |
| [Localabs](https://localabs.app/) | Advertises local MedGemma lab explanations, history, and visit questions, without an account. Its page says “Coming soon to the App Store.” | Offline lab explanation is already proposed by a focused competitor; its latency and quality claims are not independently verified. |
| [HealthWallet.me](https://github.com/LifeValue/HealthWallet.me/) | Public repository describing local AI extraction, offline records, provider connections, and summary export. | Even local-first records with on-device AI are not an empty category. Repository claims do not establish reliable clinical performance or adoption. |

Apple also [announced health experiences using Apple Intelligence on September 9, 2026](https://www.apple.com/newsroom/2026/09/apple-advances-health-and-fitness-capabilities-using-apple-intelligence/). The announcement describes forthcoming Health features; it is not proof that Apple covers Chippy's document-review workflow.

### Proposed user problem, not a validated market gap

Start with a person managing their own records across several providers who needs to reconstruct what a report actually said before a visit. The proposed workflow is:

1. Import a mixed set of scans and PDFs locally.
2. Review extracted names, dates, values, units, and ranges beside the original page.
3. Correct uncertain extraction and preserve the correction and its source.
4. Compare historical mentions without asserting that an old prescription is a current medication.
5. Select verified facts for a concise, source-linked appointment handoff.

The hypothesis is that clear provenance, correction, and dated evidence can reduce manual verification effort. Appointment preparation and privacy are not claimed as novel. Confirm the hypothesis with actual users and competitor trials: give participants the same record-review task, measure time to find and verify facts, record mistakes, and ask whether they would replace their current method. If established alternatives solve it adequately, a commercial rewrite is not justified; the project may still be useful as a personal tool.

## What on-device AI can and cannot replace

“Gemini on-device” means replacing a hosted model with a different local model. Gemini API models do not become local by changing an endpoint.

### Apple Foundation Models: preferred first candidate for bounded tasks

[Apple's framework](https://developer.apple.com/videos/play/wwdc2025/286/) provides an OS-managed local model and guided structured generation. Apple describes it as suitable for extraction, classification, and summarization rather than advanced reasoning. Constrained output shape does not establish that the extracted facts are correct.

For the current SDK baseline, budget conservatively around the documented [4,096-token session context](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window). Instructions, schemas, source content, and responses all consume that budget. Process pages or sections separately, retain original text, and retrieve a bounded amount of context. Do not concatenate a full medical history into a session. Recheck limits when upgrading model/OS versions.

[Availability depends on device and region and must be checked at runtime](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel). A recent iOS deployment target alone does not guarantee an available model. Disabled intelligence, model downloads, unsupported language, refusal, and context overflow need usable fallback states. Basic import, search, preview, and manual correction should remain functional without AI.

[Apple documents guardrail behavior for sensitive content](https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output). Its [acceptable-use requirements](https://developer.apple.com/support/terms/acceptable-use-requirements-for-the-foundation-models-framework) prohibit dangerous outputs and certain unsupervised high-impact decisions, including medical ones, and prohibit bypassing guardrails. These requirements are not a blanket prohibition on organizing medical text, nor a guarantee that a particular prompt will work. Treat source-grounded transformation as an evaluation candidate and handle refusal normally.

### Bundled local model: secondary candidate if the first evaluation fails

[MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm) provides inference, embedding, and generation libraries. A bundled model adds weight distribution, licensing, download integrity, memory, thermal, and performance responsibilities. Use a pinned version compatible with Xcode 26.4; the repository's newer Foundation Models bridge requires the 27 SDK and is not appropriate for the installed toolchain.

[MedGemma 1.5 4B](https://developers.google.com/health-ai-developer-foundations/medgemma/model-card) includes medical document extraction among its capabilities. Google requires use-case validation and describes outputs as preliminary; the model is not optimized for multi-turn use. This makes it an extraction benchmark candidate, not a validated patient chatbot. Published long-context support does not prove that an iPhone has enough memory for that context.

Do not select a model by parameter count or medical benchmark ranking alone. Quantization, prompt, runtime, device, and actual document layouts affect results. No local model was downloaded or benchmarked in this session, and no device latency or quality comparison is claimed.

### Three plausible routes

| Route | Strength | Cost or limitation | Decision |
| --- | --- | --- | --- |
| Harden existing cloud MVP | Reuses current pipeline and has minimal migration cost. | Keeps upload dependency and provider/privacy overhead; limited differentiation. | Repair it as the baseline and retain it for comparison. |
| Local-first organizer with bounded Apple-model assistance | Native integration, useful offline core, bounded AI surface. | Hardware/availability limits; extraction and refusals must be evaluated. | Recommended direction, subject to purpose and design review. |
| Full bundled-model replacement | Greater model/runtime control and local execution. | Large model distribution and performance burden; accuracy is unproven. | Evaluate only if offline requirements or measured Apple-model failures justify it. |

## Proposed architecture boundary

Retain the native UI and protected local documents. Make document text, page provenance, reviewed facts, and search usable locally. Introduce a small analysis interface so an on-device implementation and the existing server implementation can be compared without rewriting views. Start with text/page search and typed date/value filters; do not require a new vector database or embedding model for the first local milestone.

Local generation must produce candidate facts tied to document/page/text evidence. Preserve raw values and unknown fields, and distinguish extracted, user-confirmed, and user-corrected data. Search and chronological comparisons should not rely on generative arithmetic or guesses about current medication status. Document text is untrusted content, not an instruction to the model or app.

If cloud assistance remains, make it an explicit user-selected operation with a preview of the data shared. Never upload silently because local inference fails. Local mode must not call upload, backend chat, explanation, or embedding endpoints. Backend account/storage migration is a separate milestone; switching generation locally while keeping mandatory server uploads does not fulfill a local-data promise.

## Confirmed repair scope

Read-only investigation found the following in the current repository:

| Gap | Evidence | Acceptance check |
| --- | --- | --- |
| Cross-user retrieval | `query_engine.py` builds filters but does not supply them to `as_retriever`. A real Chroma/LlamaIndex probe with synthetic users alpha and beta retrieved both for alpha's request. | Two-user retrieval test returns only the requesting user's nodes; optional document filter also applies; unexpected node ownership fails closed. |
| Vector deletion | Delete endpoints do not call the helper. The current Chroma helper calls `delete` without required `ref_doc_id` and raises `TypeError`. | Document/account deletion removes exactly the target vectors and preserves another user's vectors; cleanup failure is surfaced and retryable. |
| Local file cleanup | Repository deletion removes SwiftData rows; settings clears models but does not remove document files. Imported same-name PDFs overwrite an existing local path. | Unique local file identity; exact document cleanup; delete-all cleans managed files; failure preserves retry information. |
| OCR coverage | Scans OCR `images.first`; imported PDFs send empty OCR. | Multi-page scan and image-only PDF tests preserve every page; native PDF text is retained where usable; blank/corrupt input gives a clear error. |
| Cloud-analysis permission | Onboarding is skippable and does not gate upload/AI calls with explicit consent. | Decline/cancel sends no file or health text; consent gates import upload, retry, chat, and explanations. |
| Verification coverage | iOS tests are template examples; no project-authored backend tests were found outside the virtual environment. | Relevant regression tests, unsigned build, synthetic-data flow checks, and rendered interaction inspection. |
| Documentation and release work | Stale model/status comments and unchecked release tasks remain. | Update claims only against verified behavior; keep physical-device and App Store Connect steps visibly pending. |

Additional data-lifecycle checks belong in the repair design: in-flight ingestion must not recreate vectors after deletion; ingestion retries should not duplicate chunks/events; local cached data must not leak across sign-ins. Current refresh tokens are stateless and logout does not revoke them, despite stronger wording in older docs. Do not describe those properties as fixed without implementing and testing the lifecycle.

The migration contains RLS policies, but the backend service-role client bypasses them. API filters remain essential; this session did not inspect or change deployed database policies. No claim is made that live Supabase or Qdrant configuration matches the files.

## Milestones and proposed evaluation gates

1. **Repair the baseline:** isolation, complete deletion, OCR, consent, and relevant tests. Preserve the current deployment target and unrelated files. Code changes await the concrete repair-design approval requested in chat.
2. **Evaluate local extraction:** synthetic/de-identified fixtures with manually labeled document/page/date/value/unit/range facts. Compare the current hosted pipeline, Apple-model extraction, and deterministic extraction where appropriate. Include noisy multi-page scans, repeated tests, old medication mentions, ambiguous dates, blank pages, and document prompt injection.
3. **Select the local boundary:** measure exact-field accuracy, unsupported factual claims, source validity, refusal handling, cold/warm latency, peak memory, thermal behavior, and cancellation on an actual supported iPhone. Proposed gate: every displayed fact resolves to source evidence; zero invented critical values on the evaluation set; any uncertain result stays reviewable. This is a project acceptance proposal, not a guarantee of medical safety or a population accuracy estimate.
4. **Build local-first workflow:** no-login document core, reviewed timeline, search, then selected-fact handoff. Test in airplane mode and verify outbound network behavior. Migrate existing users/data explicitly if that becomes necessary.
5. **Prepare release:** icon and privacy materials, accessibility/VoiceOver on device, distribution signing, TestFlight record/build submission, and external beta feedback. These are not completed by a simulator build.

Validation commands for the repair milestone:

```sh
cd backend
.venv/bin/python -m pytest tests -q
```

```sh
xcodebuild -project ios/Chippy/Chippy.xcodeproj -scheme Chippy \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/chippy-derived \
  CODE_SIGNING_ALLOWED=NO build
```

The backend tests directory is to be created during the authorized repair milestone; the command above is a planned check, not an already-passing result. Choose an installed simulator for UI tests rather than guessing a device name.

## Critique and revision

- **Correctness:** source links and structured generation alone cannot verify truth. Revised the proposal to require reviewable candidate facts and exact-field evaluation.
- **Simplicity:** a wholesale backend/model rewrite would mix too many uncertainties. Separate baseline repairs, bounded local evaluation, and eventual migration.
- **Privacy:** moving only inference is insufficient. Explicitly require no implicit uploads in local mode and test outbound behavior.
- **Maintainability:** avoid depending on the newest MLX bridge when the installed SDK is 26.4. Keep inference behind a small app-owned boundary.
- **Testing:** simulator tests cannot establish camera/OCR-device behavior or local-model latency. Keep physical-device gates explicit.
- **User experience:** unsupported devices and refused analyses must still support manual organization and source search.
- **Product:** offline operation and appointment preparation already have competitors. Keep the record-verification workflow labeled as a hypothesis until actual comparisons support it.

## Privacy/release context

[Apple's App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) require disclosure and explicit permission before sharing personal data with third-party AI. On-device processing reduces exposure but does not, by itself, establish regulatory compliance. The [FTC's mobile health app tool](https://www.ftc.gov/business-guidance/resources/mobile-health-apps-interactive-tool) describes obligations that can apply beyond HIPAA; applicability depends on the actual product and data flow. Older notes claiming user-uploaded records inherently avoid compliance needs should not be treated as a legal conclusion.

## Evidence status

- Completed: official/provider-source review, code-path inspection, synthetic reproduction of retrieval leakage and broken Chroma deletion.
- Completed: baseline unsigned Debug simulator build using Xcode 26.4 and `CODE_SIGNING_ALLOWED=NO`, with `** BUILD SUCCEEDED **` in `/private/tmp/chippy-baseline-build.log`. This verifies compilation of the existing code, not behavior or local-inference feasibility. The App Intents metadata tool noted that no AppIntents dependency was present.
- Not completed: product repairs, local inference benchmark, live-service verification, user research, device accessibility review, or release submission.
