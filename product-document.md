# Product Document — Personal Health Records AI (iOS)

**Tags:** #product #medtech #ios #swift #health-records
**Related:** [[wiki/healthrecords-ai-app/architecture]], [[wiki/healthrecords-ai-app/swift-ios-research]], [[wiki/medtech-ai/regulatory]]
**Status:** Planning — v1 scope defined
**Last Updated:** 2026-04-06

---

## 1. Product Overview

### Name (working title)
**Chippy** — *Your health history, finally clear.*

### One-Liner
An iOS app that turns your pile of confusing medical documents into a coherent, searchable health timeline — explained in plain language by AI.

### The Problem
Every patient accumulates a chaotic pile of health documents:
- Lab results full of numbers and ranges they don't understand
- Discharge summaries written in clinical shorthand
- Radiology reports with "incidental findings" that sound alarming but might be nothing
- Insurance EOBs (Explanation of Benefits) no one can decode
- Specialist letters scattered across providers with no coherent summary

No single tool connects these dots. Patients show up to appointments without a clear picture of their own health history. They Google medical terms in a panic. They lose track of medications. They can't answer "when did you first notice X?"

### The Solution
An iOS app where users scan or import their medical documents, and an AI agent:
1. Extracts key medical information (diagnoses, medications, lab values, dates, providers)
2. Builds a chronological health timeline across all documents
3. Explains everything in plain language
4. Answers questions about their records conversationally
5. Prepares them for upcoming appointments
6. Spots patterns and gaps over time

### Why iOS / Swift
- **VisionKit** — built-in document scanner with perspective correction, better UX than any web upload
- **PDFKit** — native PDF rendering and text extraction
- **HealthKit** — can pull FHIR clinical records and vitals from Apple Health to complement uploaded documents
- **On-device OCR** — Vision framework keeps initial processing private
- **Natural health app behavior** — people reach for their phone in medical settings

---

## 2. Target Users

### Primary: The Actively Engaged Patient
- Age 30–65
- Managing one or more chronic conditions (diabetes, hypertension, thyroid, autoimmune)
- Sees 2+ specialists, accumulates documents across multiple health systems
- Frustrated by not understanding their own records
- Willing to pay for something that genuinely helps them

### Secondary: The Caregiver
- Family member managing care for an elderly parent or chronically ill child
- Responsible for tracking records across multiple providers
- Needs to prepare for appointments and communicate with the healthcare team

### Out of Scope (v1)
- Clinicians (different workflow, different product)
- Users looking for a diagnosis tool (we are not that)
- Enterprise / health system buyers (v3+)

---

## 3. Core Features

### v1 — MVP (Target: 8 weeks)

#### F1: Document Import
- Scan documents with camera (VisionKit — automatic edge detection + enhancement)
- Import PDFs from Files app (UIDocumentPickerViewController)
- Import images (JPEG, PNG, HEIC) from Photos
- Multi-page scanning in one session
- Automatic OCR on scanned images (Vision framework, on-device)

#### F2: Document Library
- List view of all imported documents
- Thumbnail preview
- Filter by type (Lab Result, Discharge Summary, Radiology, Prescription, Insurance, Other)
- Manual label correction if AI mis-categorizes
- Delete with confirmation

#### F3: AI Processing Pipeline
- Automatic document type detection
- Structured extraction: diagnoses, medications, lab values + reference ranges, dates, provider names
- Plain-language summary of each document
- Identification of key findings

#### F4: Health Timeline
- Chronological view of all health events across documents
- Color-coded by category (labs, procedures, diagnoses, medications)
- Tap any event for detail and original document
- Date range filtering

#### F5: AI Chat (Q&A over records)
- Conversational interface to ask questions about their records
- Streaming responses
- Grounded in uploaded documents — cites sources
- Examples: "When was my last A1C?", "What medications am I currently on?", "What did the cardiologist say about my heart?"

#### F6: Document Explainer
- Tap any document → get plain-language explanation
- Medical term definitions inline
- "What does this mean for me?" summary

#### F7: Auth + Security
- Email/password sign-up
- JWT authentication
- Face ID / Touch ID app lock
- All health data encrypted at rest (NSFileProtectionComplete)
- Tokens stored in Keychain only

---

### v2 (Target: month 3–5)

#### F8: Appointment Prep
- Select an upcoming appointment (specialty)
- AI generates: "5 questions to ask your cardiologist" based on recent records
- Summary of relevant recent results to bring

#### F9: HealthKit Integration
- Connect Apple Health
- Pull FHIR clinical records (labs, conditions, medications, vitals) from connected health institutions
- Merge into timeline alongside uploaded documents
- Pull quantitative vitals (BP, glucose, HR) for trend overlay

#### F10: Pattern & Gap Detection
- "You haven't had a cholesterol panel in 3 years"
- "Your ferritin has been low in 4 of your last 5 blood draws"
- "Your blood pressure readings have been trending up since October"

#### F11: Medication Reconciliation
- Current medication list synthesized from all documents
- Flag discrepancies (provider A says 10mg, provider B says 20mg)
- "Are you still taking this?" check-in

---

### v3 (Future)

- Provider summary PDF export (shareable with doctor)
- Family health account (manage multiple people's records)
- Wearable trend overlay (diabetes companion mode)
- B2B: health system patient engagement integration

---

## 4. User Stories

### Core Flows

**US-01: Scan a lab result**
> As a user, I want to scan my paper lab result with my phone camera so I can have it in the app without manual typing.

Acceptance criteria:
- Camera opens with document scanning UI (VisionKit)
- System auto-detects document edges
- Multi-page supported
- Preview before confirming
- Processing begins automatically after confirmation

**US-02: Understand a document**
> As a user, I want to tap on any document and get a plain-language explanation so I understand what it means without Googling.

Acceptance criteria:
- Every document has an "Explain this" button
- Response streams in (not a spinner wait)
- Medical terms are defined in-line
- Response clearly states "this is not medical advice"

**US-03: Ask a question**
> As a user, I want to ask "what medications am I on?" and get an answer based on my actual documents.

Acceptance criteria:
- Chat interface accessible from home screen
- Response cites which documents the answer comes from
- Responses stream in real-time
- Cannot answer questions without records context (no hallucination)

**US-04: View my health timeline**
> As a user, I want to see all my health events in one chronological view so I can understand my health history at a glance.

Acceptance criteria:
- All documents represented as events on timeline
- Color-coded by type
- Tapping an event shows detail + original document
- Filterable by date range and category

**US-05: Secure my data**
> As a user, I want my health data to be private and require Face ID to access.

Acceptance criteria:
- Face ID / passcode required on app open
- Data encrypted at rest
- No data sent to third parties without explicit consent confirmation
- Privacy policy shown during onboarding

---

## 5. Non-Goals (v1)

- ❌ Diagnosing conditions
- ❌ Recommending treatments or medications
- ❌ Replacing a doctor
- ❌ Real-time health monitoring
- ❌ Integration with EHR systems
- ❌ Android / web version
- ❌ Multi-user (family) accounts
- ❌ Insurance claim processing

---

## 6. Regulatory & Compliance

### FDA
- **Category:** General wellness tool + informational software
- **FDA clearance required:** No
- **Key framing:** "For informational purposes only. Not a substitute for professional medical advice."
- CDS exemption: AI reasoning is visible to user; they can independently review

### HIPAA
- v1 strategy: user provides their own data — not PHI in the HIPAA sense
- Backend stores documents on behalf of users (not providers)
- If we add provider integrations → need HIPAA-compliant infrastructure + BAA with AI provider
- Gemini/Claude enterprise API → BAA available for future compliance path

### Apple App Store
- HealthKit entitlement required for v2 (clinical records needs additional Apple approval)
- Privacy policy mandatory before first use
- Third-party AI data usage disclosure required (consent before first analysis)
- Health data cannot be used for advertising
- Health data cannot be synced to iCloud

---

## 7. Success Metrics

### v1 Launch (first 90 days)
- 500 active users
- 3+ documents uploaded per user per week
- D30 retention ≥ 25%
- Chat Q&A satisfaction: 4+ stars in-app rating
- 0 security incidents

### v2
- 2,000 active users
- HealthKit connection rate ≥ 40% of users
- Appointment prep feature used by ≥ 30% before appointments
- NPS ≥ 50

---

## 8. Monetization

### Freemium Model
| Tier | Price | What You Get |
|------|-------|-------------|
| Free | $0 | 10 documents, basic timeline, 20 chat messages/month |
| Pro | $12.99/month | Unlimited documents, full Q&A, appointment prep, pattern detection |
| Annual | $99/year | Same as Pro, ~36% discount |

### Why Freemium
- Health is personal — users need to trust the app before paying
- Free tier demonstrates real value (first 10 docs is enough for most people to get a "wow" moment)
- App Store subscription infrastructure is built into StoreKit 2

---

## 9. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| OCR quality on handwritten/complex docs | Medium | High | Server-side fallback + "low confidence" flag to user |
| Users over-rely on AI for medical decisions | Medium | High | Prominent disclaimers, conservative AI tone, "ask your doctor" CTAs |
| Apple rejects HealthKit clinical records entitlement | Medium | Medium | v1 doesn't need it; justify thoroughly in App Review notes for v2 |
| AI generates incorrect medical information | Medium | High | Ground responses strictly in uploaded documents; refuse questions requiring external medical knowledge |
| Privacy breach | Low | Very High | Encryption at rest, minimal data collection, no third-party sharing |
| Gemini/Claude API cost exceeds projections | Low | Medium | Cache analysis results; don't re-analyze unchanged documents |
