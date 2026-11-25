-- WORKLINK security: helper functions, guard triggers, row-level security and storage policies.
--
-- Key rules
--   * Job seekers own their profile, CVs, applications, saved jobs and consents.
--   * Employers see ONLY the candidates (and the CVs) that applied to their own jobs.
--   * Only admins publish or reject jobs and verify employers.
--   * Nobody can change their own role; admin accounts are created by the service role.
--   * audit_logs is readable by admins only and written only by trusted functions.

create schema if not exists private;
grant usage on schema private to authenticated, anon;

-- ---------------------------------------------------------------------------
-- Helper functions (security definer so they can be used inside policies
-- without recursive RLS checks)
-- ---------------------------------------------------------------------------
create function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  );
$$;

create function private.is_employer_member(p_employer_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.employer_members
    where employer_id = p_employer_id and user_id = auth.uid()
  );
$$;

create function private.is_employer_owner(p_employer_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.employer_members
    where employer_id = p_employer_id and user_id = auth.uid() and member_role = 'owner'
  );
$$;

-- True when the current user belongs to an employer that received an
-- application from this candidate (withdrawn applications don't count).
create function private.can_view_candidate(p_candidate_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.applications a
    join public.jobs j on j.id = a.job_id
    join public.employer_members m on m.employer_id = j.employer_id
    where a.candidate_id = p_candidate_id
      and a.status <> 'withdrawn'
      and m.user_id = auth.uid()
  );
$$;

-- True when this CV was attached to an application for one of the current user's employers.
create function private.can_view_cv(p_cv_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.applications a
    join public.jobs j on j.id = a.job_id
    join public.employer_members m on m.employer_id = j.employer_id
    where a.cv_id = p_cv_id
      and a.status <> 'withdrawn'
      and m.user_id = auth.uid()
  );
$$;

create function private.can_manage_application(p_application_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.applications a
    join public.jobs j on j.id = a.job_id
    join public.employer_members m on m.employer_id = j.employer_id
    where a.id = p_application_id and m.user_id = auth.uid()
  );
$$;

create function private.has_applied_to(p_job_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.applications where job_id = p_job_id and candidate_id = auth.uid()
  );
$$;

-- True for the service role (server code) and for direct database sessions
-- (migrations, SQL editor). API requests from anon/authenticated users always
-- carry JWT claims, so they never match.
create function private.is_trusted_backend() returns boolean
language sql stable as $$
  select coalesce(auth.jwt() ->> 'role', '') = 'service_role'
      or (auth.jwt() is null and session_user <> 'authenticator');
$$;

grant execute on all functions in schema private to authenticated, anon;

-- Write an audit entry. Callable by signed-in users for their own actions.
create function public.log_audit(
  p_action text, p_entity_type text, p_entity_id text, p_metadata jsonb default '{}'::jsonb
) returns void
language sql security definer set search_path = '' as $$
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), p_action, p_entity_type, p_entity_id, coalesce(p_metadata, '{}'::jsonb));
$$;
revoke execute on function public.log_audit(text, text, text, jsonb) from public, anon;
grant execute on function public.log_audit(text, text, text, jsonb) to authenticated;

-- Server code calls this before creating a signed download URL for a CV.
-- It checks access, writes the audit entry and returns the storage path.
create function public.record_cv_access(p_application_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_path text;
  v_cv uuid;
  v_candidate uuid;
begin
  select c.pdf_path, c.id, a.candidate_id into v_path, v_cv, v_candidate
  from public.applications a
  join public.candidate_cvs c on c.id = a.cv_id
  where a.id = p_application_id;

  if v_cv is null then
    raise exception 'No CV attached to this application' using errcode = 'P0002';
  end if;

  if not (auth.uid() = v_candidate or private.can_view_cv(v_cv) or private.is_admin()) then
    raise exception 'Not allowed to access this CV' using errcode = '42501';
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'cv.accessed', 'candidate_cv', v_cv::text,
          jsonb_build_object('application_id', p_application_id));

  return v_path;
end;
$$;
revoke execute on function public.record_cv_access(uuid) from public, anon;
grant execute on function public.record_cv_access(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- New users: create a profile from sign-up metadata. Role may only be
-- 'job_seeker' or 'employer'; admins are promoted by the service role.
-- ---------------------------------------------------------------------------
create function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_role public.user_role := 'job_seeker';
begin
  if new.raw_user_meta_data ->> 'role' = 'employer' then
    v_role := 'employer';
  end if;

  insert into public.profiles (id, role, full_name, phone)
  values (
    new.id,
    v_role,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'phone', '')
  );

  if v_role = 'job_seeker' then
    insert into public.candidate_profiles (user_id) values (new.id);
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------
-- Guard triggers
-- ---------------------------------------------------------------------------

-- Employers: creator becomes owner; only admins change verification.
create function private.guard_employers() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if private.is_trusted_backend() or private.is_admin() then
    if new.verification_status = 'verified'
       and (tg_op = 'INSERT' or old.verification_status <> 'verified') then
      new.verified_at := now();
      new.verified_by := auth.uid();
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.verification_status := 'pending';
    new.verified_at := null;
    new.verified_by := null;
  else
    new.created_by := old.created_by;
    new.verification_status := old.verification_status;
    new.verified_at := old.verified_at;
    new.verified_by := old.verified_by;
  end if;
  return new;
end;
$$;
create trigger employers_guard before insert or update on public.employers
  for each row execute function private.guard_employers();

create function private.add_employer_owner() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.employer_members (employer_id, user_id, member_role)
  values (new.id, new.created_by, 'owner')
  on conflict do nothing;
  return new;
end;
$$;
create trigger employers_add_owner after insert on public.employers
  for each row execute function private.add_employer_owner();

-- Jobs: employers draft, submit for review and close; only admins publish or reject.
create function private.guard_jobs() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_verified boolean;
begin
  if tg_op = 'INSERT' and auth.uid() is not null then
    new.created_by := auth.uid();
  end if;

  if private.is_trusted_backend() or private.is_admin() then
    if new.status = 'published' and (tg_op = 'INSERT' or old.status <> 'published') then
      select verification_status = 'verified' into v_verified
      from public.employers where id = new.employer_id;
      if not coalesce(v_verified, false) then
        raise exception 'Employer must be verified before a job is published' using errcode = '42501';
      end if;
      new.published_at := now();
      insert into public.audit_logs (actor_id, action, entity_type, entity_id)
      values (auth.uid(), 'job.published', 'job', new.id::text);
    end if;
    return new;
  end if;

  -- Employer members.
  if tg_op = 'INSERT' then
    if new.status not in ('draft', 'pending_review') then
      raise exception 'New jobs must be draft or pending review' using errcode = '42501';
    end if;
    new.published_at := null;
    new.rejection_reason := null;
    new.listing_tier := 'starter';   -- tier is set by billing / admin
    return new;
  end if;

  new.employer_id := old.employer_id;
  new.created_by := old.created_by;
  new.published_at := old.published_at;
  new.rejection_reason := old.rejection_reason;
  new.listing_tier := old.listing_tier;

  if new.status is distinct from old.status then
    if not (
      (old.status in ('draft', 'rejected') and new.status in ('draft', 'pending_review')) or
      (old.status = 'pending_review' and new.status = 'draft') or
      (old.status in ('published', 'pending_review') and new.status = 'closed')
    ) then
      raise exception 'Employers cannot change a job from % to %', old.status, new.status
        using errcode = '42501';
    end if;
  elsif old.status = 'published' then
    -- Edits to a live job go back to moderation, except for the closing date.
    if (new.title, new.description, new.requirements, new.category_id, new.town_id, new.job_type,
        new.min_qualification, new.salary_min, new.salary_max)
       is distinct from
       (old.title, old.description, old.requirements, old.category_id, old.town_id, old.job_type,
        old.min_qualification, old.salary_min, old.salary_max) then
      new.status := 'pending_review';
    end if;
  end if;
  return new;
end;
$$;
create trigger jobs_guard before insert or update on public.jobs
  for each row execute function private.guard_jobs();

-- Applications: candidates apply and withdraw; employers move the status.
create function private.guard_applications() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_job record;
  v_is_candidate boolean;
begin
  if private.is_trusted_backend() or private.is_admin() then
    if tg_op = 'UPDATE' and new.status is distinct from old.status then
      new.status_changed_at := now();
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.candidate_id is distinct from auth.uid() then
      raise exception 'You can only apply as yourself' using errcode = '42501';
    end if;
    select status, closing_date into v_job from public.jobs where id = new.job_id;
    if v_job.status is distinct from 'published' or v_job.closing_date < current_date then
      raise exception 'This job is not open for applications' using errcode = '42501';
    end if;
    if new.cv_id is not null and not exists (
      select 1 from public.candidate_cvs where id = new.cv_id and candidate_id = new.candidate_id
    ) then
      raise exception 'CV does not belong to you' using errcode = '42501';
    end if;
    new.status := 'submitted';
    new.status_changed_at := now();
    return new;
  end if;

  -- UPDATE: identity columns never change.
  if (new.job_id, new.candidate_id, new.created_at) is distinct from
     (old.job_id, old.candidate_id, old.created_at) then
    raise exception 'Application job and candidate cannot change' using errcode = '42501';
  end if;

  v_is_candidate := old.candidate_id = auth.uid();

  if v_is_candidate then
    if (new.cv_id, new.cover_note) is distinct from (old.cv_id, old.cover_note) then
      raise exception 'Withdraw and re-apply to change your application' using errcode = '42501';
    end if;
    if new.status is distinct from old.status and new.status <> 'withdrawn' then
      raise exception 'You can only withdraw your application' using errcode = '42501';
    end if;
  else
    -- Employer member (RLS already limited the row to their jobs).
    if (new.cv_id, new.cover_note) is distinct from (old.cv_id, old.cover_note) then
      raise exception 'Employers cannot edit the candidate''s submission' using errcode = '42501';
    end if;
    if old.status = 'withdrawn' then
      raise exception 'This application was withdrawn' using errcode = '42501';
    end if;
    if new.status in ('submitted', 'withdrawn') and new.status is distinct from old.status then
      raise exception 'Employers cannot set status %', new.status using errcode = '42501';
    end if;
  end if;

  if new.status is distinct from old.status then
    new.status_changed_at := now();
  end if;
  return new;
end;
$$;
create trigger applications_guard before insert or update on public.applications
  for each row execute function private.guard_applications();

-- History, audit and notification outbox for application events.
create function private.after_application_change() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_title text;
begin
  select title into v_title from public.jobs where id = new.job_id;

  if tg_op = 'INSERT' then
    insert into public.application_status_history (application_id, from_status, to_status, changed_by)
    values (new.id, null, new.status, auth.uid());
    insert into public.notifications (user_id, channel, type, payload)
    values (new.candidate_id, 'email', 'application_received',
            jsonb_build_object('application_id', new.id, 'job_id', new.job_id, 'job_title', v_title));
    insert into public.audit_logs (actor_id, action, entity_type, entity_id)
    values (auth.uid(), 'application.submitted', 'application', new.id::text);
  elsif new.status is distinct from old.status then
    insert into public.application_status_history (application_id, from_status, to_status, changed_by)
    values (new.id, old.status, new.status, auth.uid());
    if new.status <> 'withdrawn' then
      insert into public.notifications (user_id, channel, type, payload)
      values (new.candidate_id, 'email', 'application_status_changed',
              jsonb_build_object('application_id', new.id, 'job_id', new.job_id,
                                 'job_title', v_title, 'status', new.status));
    end if;
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
    values (auth.uid(), 'application.status_changed', 'application', new.id::text,
            jsonb_build_object('from', old.status, 'to', new.status));
  end if;
  return null;
end;
$$;
create trigger applications_after_change after insert or update on public.applications
  for each row execute function private.after_application_change();

-- Consent changes are audited too.
create function private.after_consent_recorded() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), case when new.granted then 'consent.granted' else 'consent.withdrawn' end,
          'consent', new.user_id::text,
          jsonb_build_object('type', new.consent_type, 'policy_version', new.policy_version));
  return null;
end;
$$;
create trigger consent_records_audit after insert on public.consent_records
  for each row execute function private.after_consent_recorded();

-- ---------------------------------------------------------------------------
-- Column privileges: block role escalation and outbox tampering
-- ---------------------------------------------------------------------------
revoke update on public.profiles from authenticated, anon;
grant update (full_name, phone, town_id) on public.profiles to authenticated;

revoke update on public.notifications from authenticated, anon;
grant update (read_at) on public.notifications to authenticated;

revoke all on public.audit_logs from authenticated, anon;
grant select on public.audit_logs to authenticated;          -- RLS limits to admins

revoke update, delete on public.consent_records from authenticated, anon;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.candidate_profiles enable row level security;
alter table public.employers enable row level security;
alter table public.employer_members enable row level security;
alter table public.job_categories enable row level security;
alter table public.jobs enable row level security;
alter table public.candidate_cvs enable row level security;
alter table public.applications enable row level security;
alter table public.application_status_history enable row level security;
alter table public.application_notes enable row level security;
alter table public.saved_jobs enable row level security;
alter table public.notifications enable row level security;
alter table public.consent_records enable row level security;
alter table public.data_deletion_requests enable row level security;
alter table public.audit_logs enable row level security;

-- profiles
create policy "Read own profile" on public.profiles for select to authenticated
  using (id = auth.uid());
create policy "Employers read applicant profiles" on public.profiles for select to authenticated
  using (private.can_view_candidate(id));
create policy "Admins read all profiles" on public.profiles for select to authenticated
  using (private.is_admin());
create policy "Update own profile" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- candidate_profiles
create policy "Candidate manages own profile" on public.candidate_profiles for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Employers read applicant candidate profiles" on public.candidate_profiles for select to authenticated
  using (private.can_view_candidate(user_id));
create policy "Admins read candidate profiles" on public.candidate_profiles for select to authenticated
  using (private.is_admin());

-- employers
create policy "Verified employers are public" on public.employers for select
  using (verification_status = 'verified');
create policy "Members read their employer" on public.employers for select to authenticated
  using (private.is_employer_member(id));
create policy "Admins manage employers" on public.employers for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy "Employer accounts create employers" on public.employers for insert to authenticated
  with check (
    created_by = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'employer')
  );
create policy "Owners update their employer" on public.employers for update to authenticated
  using (private.is_employer_owner(id)) with check (private.is_employer_owner(id));

-- employer_members
create policy "Members see their team" on public.employer_members for select to authenticated
  using (user_id = auth.uid() or private.is_employer_member(employer_id) or private.is_admin());
create policy "Owners add team members" on public.employer_members for insert to authenticated
  with check (private.is_employer_owner(employer_id));
create policy "Owners remove team members" on public.employer_members for delete to authenticated
  using (private.is_employer_owner(employer_id) and user_id <> auth.uid());

-- job_categories
create policy "Categories are public" on public.job_categories for select using (true);

-- jobs
create policy "Open jobs are public" on public.jobs for select
  using (status = 'published' and closing_date >= current_date);
create policy "Members read their jobs" on public.jobs for select to authenticated
  using (private.is_employer_member(employer_id));
create policy "Applicants read jobs they applied to" on public.jobs for select to authenticated
  using (private.has_applied_to(id));
create policy "Admins manage jobs" on public.jobs for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy "Members create jobs" on public.jobs for insert to authenticated
  with check (private.is_employer_member(employer_id));
create policy "Members update their jobs" on public.jobs for update to authenticated
  using (private.is_employer_member(employer_id)) with check (private.is_employer_member(employer_id));
create policy "Members delete draft jobs" on public.jobs for delete to authenticated
  using (private.is_employer_member(employer_id) and status = 'draft');

-- candidate_cvs
create policy "Candidate manages own CVs" on public.candidate_cvs for all to authenticated
  using (candidate_id = auth.uid()) with check (candidate_id = auth.uid());
create policy "Employers read CVs sent to their jobs" on public.candidate_cvs for select to authenticated
  using (private.can_view_cv(id));
create policy "Admins read CVs" on public.candidate_cvs for select to authenticated
  using (private.is_admin());

-- applications
create policy "Candidate reads own applications" on public.applications for select to authenticated
  using (candidate_id = auth.uid());
create policy "Candidate applies" on public.applications for insert to authenticated
  with check (candidate_id = auth.uid());
create policy "Candidate withdraws" on public.applications for update to authenticated
  using (candidate_id = auth.uid()) with check (candidate_id = auth.uid());
create policy "Employers read applications to their jobs" on public.applications for select to authenticated
  using (private.can_manage_application(id));
create policy "Employers update applications to their jobs" on public.applications for update to authenticated
  using (private.can_manage_application(id)) with check (private.can_manage_application(id));
create policy "Admins manage applications" on public.applications for all to authenticated
  using (private.is_admin()) with check (private.is_admin());

-- application_status_history (rows written by trigger only)
create policy "Read history of visible applications" on public.application_status_history for select to authenticated
  using (exists (select 1 from public.applications a where a.id = application_id));

-- application_notes (employer-only)
create policy "Employers manage notes on their applications" on public.application_notes for all to authenticated
  using (private.can_manage_application(application_id))
  with check (private.can_manage_application(application_id) and author_id = auth.uid());
create policy "Admins read notes" on public.application_notes for select to authenticated
  using (private.is_admin());

-- saved_jobs
create policy "Candidate manages saved jobs" on public.saved_jobs for all to authenticated
  using (candidate_id = auth.uid()) with check (candidate_id = auth.uid());

-- notifications (inserted by triggers / server only)
create policy "Read own notifications" on public.notifications for select to authenticated
  using (user_id = auth.uid());
create policy "Mark own notifications read" on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- consent_records (append-only)
create policy "Read own consents" on public.consent_records for select to authenticated
  using (user_id = auth.uid() or private.is_admin());
create policy "Record own consent" on public.consent_records for insert to authenticated
  with check (user_id = auth.uid());

-- data_deletion_requests
create policy "Read own deletion requests" on public.data_deletion_requests for select to authenticated
  using (user_id = auth.uid() or private.is_admin());
create policy "Request own deletion" on public.data_deletion_requests for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending');
create policy "Admins handle deletion requests" on public.data_deletion_requests for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

-- audit_logs
create policy "Admins read audit logs" on public.audit_logs for select to authenticated
  using (private.is_admin());

-- ---------------------------------------------------------------------------
-- Storage: private 'cvs' bucket. Objects live at '<candidate_id>/<cv_id>.pdf'.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cvs', 'cvs', false, 5242880, array['application/pdf'])
on conflict (id) do nothing;

create policy "Candidates manage own CV files" on storage.objects for all to authenticated
  using (bucket_id = 'cvs' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'cvs' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Employers read CV files sent to their jobs" on storage.objects for select to authenticated
  using (
    bucket_id = 'cvs'
    and exists (
      select 1 from public.candidate_cvs c
      where c.pdf_path = storage.objects.name and private.can_view_cv(c.id)
    )
  );
