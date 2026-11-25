# WORKLINK

**Opportunities. Employment. Growth.**

WORKLINK is a mobile-first job platform (Progressive Web App) launching in Standerton, Lekwa Local Municipality,
Mpumalanga, then expanding across South Africa. It connects job seekers with employers, learnerships and internships.

- **Free for job seekers, always:** search, CV builder, PDF download, applications and tracking.
- **Employers pay:** R149 Starter ad, R249 Featured ad, R499/month Business Pro.

Owned by **Reminisce Tech**, part of Reminisce Group.

## What's in this repository

| Path | What it is |
| --- | --- |
| `apps/web` | The Next.js 16 + Tailwind CSS 4 app (installable PWA). |
| `supabase/migrations` | Database tables, row-level security and storage rules for Supabase (Postgres). |
| `supabase/tests` | Automated tests proving the security rules (e.g. employers only see their own applicants). |
| `docs/` | Setup guide, architecture, security/POPIA notes and brand guide. |
| `.github/workflows/ci.yml` | Runs the database tests and builds the app on every push and pull request. |

## Run it

**Non-technical guide (Supabase + Vercel, get a link for your phone):** [docs/getting-started.md](docs/getting-started.md)

For developers:

```bash
cd apps/web
cp ../../.env.example .env.local   # fill in your Supabase URL and publishable key
npm install
npm run dev                        # http://localhost:3000
```

Without Supabase keys the app still runs and shows clearly labelled sample jobs.

Database tests (needs a local PostgreSQL 15+, uses the standard `PG*` variables):

```bash
./supabase/tests/run.sh
```

Apply migrations to a Supabase project with the Supabase CLI (`supabase link` then `supabase db push`),
or paste the files in `supabase/migrations` into the SQL Editor in filename order.

## Stack

Next.js (App Router) · Tailwind CSS · Supabase (Postgres, Auth, Storage) · Vercel · Resend (email).
WhatsApp notifications come later, only with the user's consent.

## Status

Foundation only (v0.1): landing page, job search (sample data until Supabase is connected), employer pricing,
privacy notice draft, PWA manifest and icons, and the full V1 database with security rules.
Next: sign-up/sign-in, CV builder with PDF, employer job posting, admin moderation, email notifications.
See [docs/architecture.md](docs/architecture.md#roadmap).

## Legal

- **Employment Services Act 4 of 2014:** no fees may be charged to job seekers. Written guidance from the
  Department of Employment and Labour on Private Employment Agency registration is required before launch.
- **POPIA:** see [docs/security-and-popia.md](docs/security-and-popia.md).
