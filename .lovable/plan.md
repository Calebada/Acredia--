# ACREDIA — CIT-U AI Credit Evaluation System

A web application implementing all six modules you specified, built on Lovable Cloud (auth, Postgres, storage, AI Gateway).

## Tech foundation
- **Auth + DB + Storage**: Lovable Cloud (Supabase under the hood).
- **AI**: Lovable AI Gateway for OCR extraction (vision model on uploaded TOR images/PDF pages), subject-matching scoring, and the chatbot.
- **PDF reports**: client-side generation (jsPDF) with download + storage upload.
- **Design**: CIT-U Maroon (#7a1e2b) + Gold (#d4a747), serif display + clean sans body, institutional but modern.

## Roles
- **Guest** — landing page + chatbot (limited knowledge-base mode).
- **Applicant** — submit application, upload TOR, view evaluation, flag subjects, view forecast, download report, full chatbot.
- **Evaluator** — review queue, side-by-side TOR + AI match panel, approve/override/reject/add subjects, finalize.
- **Administrator** — manage curricula, view all applications/reports, manage users.

## Database schema
```text
profiles            (id, full_name, role, program_id, created_at)
user_roles          (user_id, role)  -- enum: applicant/evaluator/admin
programs            (id, code, name)               -- BSIT seeded
curriculum_subjects (id, program_id, code, title, description, units, year, sem, prereqs)
applications        (id, applicant_id, program_id, status, created_at, finalized_at)
tor_documents       (id, application_id, file_path, ocr_status, ocr_raw)
tor_subjects        (id, application_id, code, title, grade, units, raw_text)
subject_matches     (id, application_id, tor_subject_id, curriculum_subject_id,
                     confidence, status, evaluator_note, flagged_by_applicant)
predictions         (id, application_id, semesters_min, semesters_max, plan_json)
reports             (id, application_id, file_path, generated_at)
chat_conversations  (id, user_id|null, created_at)
chat_messages       (id, conversation_id, role, content, created_at)
```
RLS on every table; applicants see only their rows, evaluators/admins broader scope via `has_role()` security-definer function.

## Modules → screens

**Module 2 — Application & Upload**
`/apply` — multi-step form (personal info, target program, upload TOR PDF/JPG/PNG to storage bucket `tor-documents`).

**Module 3 — OCR + Matching + Review**
- `3.1 OCR` — server function calls Gemini vision model on the uploaded file, parses code/title/grade/units into `tor_subjects`. Quality threshold; prompt re-upload if too low.
- `3.2 Matching` — server function loads program curriculum, scores each TOR subject vs each curriculum subject using AI (title similarity + description keywords + units check), stores confidence 0-100. Green ≥85, Yellow 60-84, Red <60.
- `3.3 Applicant preview` — `/applicant/evaluation/:id` color-coded table, flag button + note, links to forecast and report.
- `3.4 Evaluator` — `/evaluator/queue` and `/evaluator/review/:id` with TOR preview left, match panel right; approve / override (curriculum picker) / add / reject; finalize button. Auto-finalize path when all ≥85 and no flags.

**Module 4 — Prediction**
Server function computes remaining subjects, respects prereqs + max units/sem (21), produces semester-by-semester plan. Range shown when flags pending.

**Module 5 — Report**
On finalization, generate styled PDF (applicant info, credited table, non-credited with reasons, totals, remaining, forecast, evaluator remarks, signature block), upload to `reports` bucket, link on applicant and admin dashboards.

**Module 6 — Chatbot**
Floating widget on every page. Server function streams from Lovable AI with system prompt covering ETEEAP rules, process, FAQ. For authenticated users it also receives a compact summary of their current application/evaluation. Per-session history in `chat_messages`. Escalation CTA when low-confidence answer.

## Seed data
- 1 program: **BSIT** with ~40 curriculum subjects across 8 semesters (realistic codes: IT111, IT121, GE-Math, etc., with prereqs).
- 1 demo evaluator + 1 demo admin account creation instructions in a setup note.

## Build phases (this turn)
1. **Foundation** — enable Cloud, design system, schema + RLS + seed, auth (email/password + Google), role routing, role-based dashboards shells, landing page, chatbot widget shell.
2. **Core flow** — application + TOR upload, OCR server fn, matching server fn, applicant evaluation preview, evaluator review UI, prediction engine.
3. **Polish** — PDF report generation, admin dashboard (apps + curriculum view), chatbot wired to AI Gateway with app-context, final QA pass.

## Out of scope for this MVP (call out so you know)
- True EasyOCR (Python). We use a vision LLM instead — same outcome, fits the Cloudflare Worker runtime.
- Email notifications (in-app + toast only).
- Curriculum upload UI (admin sees seeded BSIT; upload tool can come next).
- SMS/2FA.

Approve and I'll start building Phase 1 immediately.