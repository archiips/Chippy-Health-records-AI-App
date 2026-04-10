# Chippy — Your Health History, Finally Clear

Chippy is an iOS app that turns confusing medical documents into something you can actually understand. Import a prescription, lab result, or doctor's note, and Chippy reads it, pulls out the important information, and adds it to a timeline of your health history. You can also chat with an AI that has read all your documents and can answer questions like "what medications am I on?" or "what did my last blood test show?"

## Screenshots

<table>
  <tr>
    <td align="center"><img src="screenshots/Welcome back page.png" width="180"/><br/><sub>Sign In</sub></td>
    <td align="center"><img src="screenshots/Documents page.png" width="180"/><br/><sub>Document Library</sub></td>
    <td align="center"><img src="screenshots/Specific document about page.png" width="180"/><br/><sub>Document Analysis</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/Timeline page.png" width="180"/><br/><sub>Health Timeline</sub></td>
    <td align="center"><img src="screenshots/chat page.png" width="180"/><br/><sub>AI Chat</sub></td>
    <td align="center"><img src="screenshots/Settings page.png" width="180"/><br/><sub>Settings</sub></td>
  </tr>
</table>

## What It Does

**Import any medical document** — scan it with your camera, pick a PDF from Files, or import a photo. Chippy supports prescriptions, lab results, radiology reports, discharge summaries, clinical notes, and insurance documents.

**Get a plain-English summary** — after uploading, the AI reads the document and extracts the key information: medications, diagnoses, lab values, and important findings. No medical jargon.

**See your health history at a glance** — every event from every document gets added to a timeline, grouped by month and filterable by category (diagnosis, medication, lab, procedure, and more).

**Ask questions about your records** — the chat feature lets you ask anything across all your uploaded documents. It answers based only on what's actually in your files and always reminds you to consult your doctor.

## How It Works

When you upload a document, the backend runs it through a 10-step pipeline:

1. Extracts text from the PDF using PyMuPDF, or uses the on-device OCR text for images
2. Classifies the document type (lab result, prescription, etc.)
3. Splits the text into chunks using a strategy tuned for that document type
4. Converts each chunk into a vector embedding and stores it in a vector database
5. Runs a structured extraction to pull out medications, diagnoses, lab values, and health events
6. Saves everything to the database and marks the document as complete

The chat feature uses RAG (retrieval-augmented generation) — it finds the most relevant chunks from your documents and sends them to the AI along with your question, so answers are always grounded in your actual records.

## Tech Stack

| Layer | Technology |
|---|---|
| iOS App | Swift, SwiftUI, SwiftData |
| Backend | FastAPI (Python) |
| AI Extraction | Gemini 2.5 Flash |
| AI Chat | Gemini 2.5 Flash Lite |
| Embeddings | gemini-embedding-001 (3072 dimensions) |
| Vector Database | Chroma (dev) / Qdrant (prod) |
| RAG Orchestration | LlamaIndex |
| Database + Auth | Supabase (Postgres + Storage) |

## Privacy and Security

- On-device OCR runs before any file is uploaded — raw document text is extracted locally first
- All files stored with iOS data protection (encrypted at rest)
- Face ID / Touch ID lock when the app goes to the background
- JWT authentication with short-lived access tokens and rotating refresh tokens
- Every database query is filtered by user ID — no user can access another's data

## Disclaimer

Chippy is for informational purposes only. It is not a substitute for professional medical advice, diagnosis, or treatment. Always consult a qualified healthcare provider with questions about your health.
