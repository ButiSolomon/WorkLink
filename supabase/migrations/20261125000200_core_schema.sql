-- WORKLINK core schema: users and roles, candidates, employers, jobs, CVs,
-- applications, saved jobs, notifications, consent and audit logs.
-- Row-level security is defined in the next migration.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.user_role as enum ('job_seeker', 'employer', 'admin');
create type public.employer_member_role as enum ('owner', 'recruiter');
create type public.verification_status as enum ('pending', 'verified', 'rejected');
create type public.job_type as enum (
  'full_time', 'part_time', 'contract', 'temporary', 'learnership', 'internship', 'graduate_programme'
);
create type public.job_status as enum ('draft', 'pending_review', 'published', 'closed', 'rejected');
create type public.listing_tier as enum ('starter', 'featured');
create type public.qualification_level as enum (
  'none', 'grade_9', 'grade_10', 'grade_11', 'matric', 'certificate', 'diploma', 'degree', 'postgraduate'
);
create type public.application_status as enum (
  'submitted', 'viewed', 'shortlisted', 'interview', 'unsuccessful', 'hired', 'withdrawn'
);
create type public.notification_channel as enum ('email', 'whatsapp', 'in_app');
create type public.notification_status as enum ('queued', 'sent', 'failed', 'cancelled');
create type public.consent_type as enum (
  'terms_of_use', 'privacy_policy', 'share_cv_with_employers', 'email_job_alerts', 'whatsapp_notifications'
);

-- Shared trigger to maintain updated_at.
create function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Users and roles (one row per auth.users row)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null default 'job_seeker',
  full_name text not null default '',
  phone text,                                  -- E.164, e.g. +27821234567
  town_id integer references public.towns (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Job seekers
-- ---------------------------------------------------------------------------
create table public.candidate_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  headline text,                               -- e.g. "Forklift operator with 3 years' experience"
  career_objective text,
  highest_qualification public.qualification_level not null default 'none',
  has_drivers_licence boolean not null default false,
  drivers_licence_code text,                   -- e.g. 'B', 'C1', 'EC'
  languages text[] not null default '{}',
  skills text[] not null default '{}',
  available_from date,
  willing_to_relocate boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger candidate_profiles_updated_at before update on public.candidate_profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Employers
-- ---------------------------------------------------------------------------
create table public.employers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  registration_number text,                    -- CIPC number, optional for sole traders
  industry text,
  about text,
  website text,
  contact_email text,
  contact_phone text,
  town_id integer references public.towns (id),
  verification_status public.verification_status not null default 'pending',
  verified_at timestamptz,
  verified_by uuid references public.profiles (id),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger employers_updated_at before update on public.employers
  for each row execute function public.set_updated_at();

-- People who can act for an employer.
create table public.employer_members (
  employer_id uuid not null references public.employers (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  member_role public.employer_member_role not null default 'recruiter',
  created_at timestamptz not null default now(),
  primary key (employer_id, user_id)
);
create index employer_members_user_idx on public.employer_members (user_id);

-- ---------------------------------------------------------------------------
-- Jobs
-- ---------------------------------------------------------------------------
create table public.job_categories (
  id smallint generated always as identity primary key,
  name text not null unique,
  slug text not null unique
);

insert into public.job_categories (name, slug) values
  ('Agriculture and Farming', 'agriculture'),
  ('Admin and Office', 'admin-office'),
  ('Retail and Sales', 'retail-sales'),
  ('Hospitality and Food', 'hospitality'),
  ('Manufacturing and Production', 'manufacturing'),
  ('Mining and Energy', 'mining-energy'),
  ('Construction and Trades', 'construction-trades'),
  ('Transport and Logistics', 'transport-logistics'),
  ('Security', 'security'),
  ('Cleaning and Domestic', 'cleaning-domestic'),
  ('Healthcare and Care Work', 'healthcare'),
  ('Education and Training', 'education'),
  ('IT and Technology', 'it-technology'),
  ('Finance and Accounting', 'finance'),
  ('Government and Public Service', 'public-service'),
  ('Learnerships and Internships', 'learnerships-internships');

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.employers (id) on delete cascade,
  category_id smallint references public.job_categories (id),
  town_id integer not null references public.towns (id),
  title text not null check (char_length(title) between 3 and 120),
  description text not null,
  requirements text,
  job_type public.job_type not null default 'full_time',
  min_qualification public.qualification_level not null default 'none',
  experience_required boolean not null default false,
  salary_min integer check (salary_min >= 0),  -- Rand per month
  salary_max integer check (salary_max >= 0),
  salary_negotiable boolean not null default false,
  positions integer not null default 1 check (positions > 0),
  closing_date date not null,
  status public.job_status not null default 'draft',
  listing_tier public.listing_tier not null default 'starter',
  rejection_reason text,
  published_at timestamptz,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (salary_max is null or salary_min is null or salary_max >= salary_min)
);
create index jobs_public_idx on public.jobs (status, closing_date) where status = 'published';
create index jobs_employer_idx on public.jobs (employer_id);
create index jobs_town_idx on public.jobs (town_id);
create index jobs_category_idx on public.jobs (category_id);
create trigger jobs_updated_at before update on public.jobs
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- CVs (built with the CV builder; PDF stored in the private 'cvs' bucket)
-- ---------------------------------------------------------------------------
create table public.candidate_cvs (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles (user_id) on delete cascade,
  title text not null default 'My CV',
  template text not null default 'classic' check (template in ('classic', 'modern', 'simple')),
  content jsonb not null default '{}'::jsonb,  -- personal info, objective, education, experience, skills, references, certificates
  pdf_path text,                               -- storage object name: '<candidate_id>/<cv_id>.pdf'
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index candidate_cvs_candidate_idx on public.candidate_cvs (candidate_id);
create unique index candidate_cvs_one_primary on public.candidate_cvs (candidate_id) where is_primary;
create trigger candidate_cvs_updated_at before update on public.candidate_cvs
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Applications
-- ---------------------------------------------------------------------------
create table public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  candidate_id uuid not null references public.candidate_profiles (user_id) on delete cascade,
  cv_id uuid references public.candidate_cvs (id) on delete set null,
  cover_note text check (char_length(cover_note) <= 2000),
  status public.application_status not null default 'submitted',
  status_changed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (job_id, candidate_id)
);
create index applications_candidate_idx on public.applications (candidate_id);
create index applications_job_idx on public.applications (job_id);
create trigger applications_updated_at before update on public.applications
  for each row execute function public.set_updated_at();

create table public.application_status_history (
  id bigint generated always as identity primary key,
  application_id uuid not null references public.applications (id) on delete cascade,
  from_status public.application_status,
  to_status public.application_status not null,
  changed_by uuid references public.profiles (id) on delete set null,
  changed_at timestamptz not null default now()
);
create index application_status_history_app_idx on public.application_status_history (application_id);

-- Employer-only notes, kept out of the applications table so candidates never see them.
create table public.application_notes (
  id bigint generated always as identity primary key,
  application_id uuid not null references public.applications (id) on delete cascade,
  author_id uuid references public.profiles (id) on delete set null,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index application_notes_app_idx on public.application_notes (application_id);

-- ---------------------------------------------------------------------------
-- Saved jobs
-- ---------------------------------------------------------------------------
create table public.saved_jobs (
  candidate_id uuid not null references public.candidate_profiles (user_id) on delete cascade,
  job_id uuid not null references public.jobs (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (candidate_id, job_id)
);

-- ---------------------------------------------------------------------------
-- Notifications (outbox; a server worker sends queued rows via Resend / WhatsApp)
-- ---------------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  channel public.notification_channel not null default 'email',
  type text not null,                          -- e.g. 'application_received', 'status_changed', 'job_alert', 'closing_reminder'
  payload jsonb not null default '{}'::jsonb,
  status public.notification_status not null default 'queued',
  read_at timestamptz,
  sent_at timestamptz,
  error text,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index notifications_queue_idx on public.notifications (status, channel) where status = 'queued';

-- ---------------------------------------------------------------------------
-- POPIA: consent records (append-only) and deletion requests
-- ---------------------------------------------------------------------------
create table public.consent_records (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  consent_type public.consent_type not null,
  granted boolean not null,                    -- false = withdrawal
  policy_version text not null,                -- e.g. 'privacy-2026-11'
  source text not null default 'web',
  recorded_at timestamptz not null default now()
);
create index consent_records_user_idx on public.consent_records (user_id, consent_type, recorded_at desc);

-- Latest decision per user and consent type.
create view public.current_consents with (security_invoker = true) as
select distinct on (user_id, consent_type)
  user_id, consent_type, granted, policy_version, recorded_at
from public.consent_records
order by user_id, consent_type, recorded_at desc, id desc;

create table public.data_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  reason text,
  status text not null default 'pending' check (status in ('pending', 'completed', 'rejected')),
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  handled_by uuid references public.profiles (id) on delete set null
);

-- ---------------------------------------------------------------------------
-- Audit log (written only by security-definer functions and triggers)
-- ---------------------------------------------------------------------------
create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid,                               -- no FK: logs outlive deleted users
  action text not null,                        -- e.g. 'cv.downloaded', 'application.status_changed', 'job.published'
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_entity_idx on public.audit_logs (entity_type, entity_id);
create index audit_logs_actor_idx on public.audit_logs (actor_id, created_at desc);
