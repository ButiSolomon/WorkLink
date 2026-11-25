# Architecture

```
Phone / tablet / computer (installable PWA)
        │  HTTPS
        ▼
Next.js app on Vercel (apps/web)
  - Server Components read data as the signed-in user
  - proxy.ts keeps the Supabase session fresh
        │  Supabase client (publishable key + user session)
        ▼
Supabase
  - Postgres with row-level security (supabase/migrations)
  - Auth (email / phone sign-in)
  - Storage: private "cvs" bucket for CV PDFs
  - notifications table = outbox → worker sends email (Resend), later WhatsApp
```

Security lives in the database, not only in the app: every table has row-level security, so even a bug in the
web app cannot show one employer another employer's applicants.

## Data model

| Table | Purpose |
| --- | --- |
| `provinces`, `municipalities`, `towns` | Location hierarchy. Seeded with all 9 provinces and Lekwa (Standerton, Sakhile, Morgenzon, Thuthukani). |
| `profiles` | One row per user. `role` = `job_seeker`, `employer` or `admin`. Created automatically on sign-up. |
| `candidate_profiles` | Job seeker details: qualification, licence, languages, skills, availability. |
| `employers`, `employer_members` | Companies, verification status, and the people who recruit for them. |
| `job_categories` | 16 starter categories (agriculture, retail, learnerships …). |
| `jobs` | Vacancies, learnerships and internships. `status`: draft → pending_review → published → closed. |
| `candidate_cvs` | CV builder content (JSON) and the stored PDF path. Templates: classic, modern, simple. |
| `applications`, `application_status_history` | Applications and every status change. |
| `application_notes` | Employer-only notes, never visible to the candidate. |
| `saved_jobs` | Jobs a candidate bookmarked. |
| `notifications` | Outbox for email / WhatsApp / in-app messages, filled by database triggers. |
| `consent_records`, `current_consents` | Append-only POPIA consent history and the latest decision per type. |
| `data_deletion_requests` | POPIA deletion requests handled by admins. |
| `audit_logs` | Who did what: CV access, status changes, job publishing, consent. Admin-only. |

## Access rules (enforced by RLS, tested in `supabase/tests/rls_test.sql`)

- Job seekers manage only their own profile, CVs, applications, saved jobs and consents.
- Employers see a candidate's profile and CV **only** while that candidate has an active application to one of
  their jobs. Withdrawing an application removes that access.
- Employers can draft, submit and close jobs. Only admins publish or reject, and only for verified employers.
  Editing a live job sends it back to review.
- Candidates can only withdraw their application; employers can only move its status forward.
- Nobody can change their own role. Admins are promoted with the service role.
- CV downloads go through `record_cv_access()`, which checks access and writes an audit entry.
- Anonymous visitors see only open jobs, verified employers, categories and locations.

## Roadmap

1. **Foundation** (this release): schema, security, PWA shell, job search, pricing, privacy draft.
2. Sign-up / sign-in (email, then phone OTP), consent capture at sign-up.
3. Candidate profile and CV builder with PDF download (3 templates).
4. Employer onboarding, verification upload, job posting.
5. Admin moderation: verify employers, publish/reject jobs, deletion requests.
6. Applications and tracking; email notifications via Resend.
7. Payments for employer plans (PayFast or Yoco).
8. WhatsApp notifications with opt-in, offline support, launch in Standerton.
