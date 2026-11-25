-- Row-level security tests. Run after the stub and all migrations:
--   ./supabase/tests/run.sh
-- Every check raises an exception on failure, so the script stops at the first broken rule.
\set ON_ERROR_STOP 1
set client_min_messages = warning;

create schema test;
grant usage on schema test to anon, authenticated;

-- Switch identity the way PostgREST does: role + JWT claims.
create function test.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, false);
  execute 'set role authenticated';
end; $$;

create function test.act_as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, false);
  execute 'set role anon';
end; $$;

create function test.reset() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', false);
end; $$;

create function test.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FAILED: %', p_msg; end if;
  raise notice 'ok: %', p_msg;
end; $$;

-- Run a statement that must fail.
create function test.expect_error(p_sql text, p_msg text) returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    raise notice 'ok: % (%)', p_msg, sqlerrm;
    return;
  end;
  raise exception 'FAILED (no error): %', p_msg;
end; $$;
grant execute on all functions in schema test to anon, authenticated;

-- Fixed ids make the script readable.
\set seeker_a '''aaaaaaaa-0000-0000-0000-000000000001'''
\set seeker_b '''aaaaaaaa-0000-0000-0000-000000000002'''
\set emp_1    '''eeeeeeee-0000-0000-0000-000000000001'''
\set emp_2    '''eeeeeeee-0000-0000-0000-000000000002'''
\set admin    '''dddddddd-0000-0000-0000-000000000001'''

insert into auth.users (id, email, raw_user_meta_data) values
  (:seeker_a, 'a@example.test', '{"full_name":"Thandi A","role":"job_seeker"}'),
  (:seeker_b, 'b@example.test', '{"full_name":"Sipho B"}'),
  (:emp_1,    'e1@example.test', '{"full_name":"Employer One","role":"employer"}'),
  (:emp_2,    'e2@example.test', '{"full_name":"Employer Two","role":"employer"}'),
  (:admin,    'admin@example.test', '{"full_name":"Admin","role":"admin"}');

select test.expect((select role from public.profiles where id = :admin) = 'job_seeker',
  'sign-up cannot self-assign admin');
update public.profiles set role = 'admin' where id = :admin;   -- service role promotes

-- Role escalation ----------------------------------------------------------
select test.act_as(:seeker_a);
select test.expect_error($$update public.profiles set role = 'admin' where id = auth.uid()$$,
  'job seeker cannot change own role');
update public.profiles set full_name = 'Thandi Afrika' where id = auth.uid();
select test.expect((select full_name from public.profiles where id = auth.uid()) = 'Thandi Afrika',
  'job seeker can edit own name');
select test.expect_error($$insert into public.employers (name, slug, created_by) values ('X', 'x', auth.uid())$$,
  'job seeker cannot create an employer');
select test.reset();

-- Employers ----------------------------------------------------------------
select test.act_as(:emp_1);
insert into public.employers (id, name, slug, created_by, verification_status)
  values ('11111111-0000-0000-0000-000000000001', 'Lekwa Dairy', 'lekwa-dairy', :emp_1, 'verified');
select test.expect((select verification_status from public.employers where slug = 'lekwa-dairy') = 'pending',
  'employer cannot self-verify');
select test.expect(exists (select 1 from public.employer_members
  where employer_id = '11111111-0000-0000-0000-000000000001' and user_id = :emp_1 and member_role = 'owner'),
  'creator becomes owner');
select test.reset();

select test.act_as(:emp_2);
insert into public.employers (id, name, slug, created_by)
  values ('11111111-0000-0000-0000-000000000002', 'Standerton Retail', 'standerton-retail', :emp_2);
select test.expect((select count(*) from public.employers) = 1, 'employer 2 sees only own unverified employer');
select test.reset();

select test.act_as(:admin);
update public.employers set verification_status = 'verified';
select test.expect((select count(*) from public.employers where verified_at is not null) = 2, 'admin verifies employers');
select test.reset();

-- Jobs ---------------------------------------------------------------------
select test.act_as(:emp_1);
insert into public.jobs (id, employer_id, town_id, title, description, closing_date, status, category_id, created_by)
  values ('22222222-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001',
          (select id from public.towns where slug = 'standerton'), 'Dairy general worker',
          'Milking and cleaning', current_date + 14, 'pending_review', 1, :emp_1);
select test.expect_error($$update public.jobs set status = 'published' where id = '22222222-0000-0000-0000-000000000001'$$,
  'employer cannot publish own job');
select test.expect_error($$insert into public.jobs (employer_id, town_id, title, description, closing_date, status, created_by)
  values ('11111111-0000-0000-0000-000000000002', 1, 'Hijack', 'x', current_date + 5, 'draft', auth.uid())$$,
  'employer cannot post for another employer');
insert into public.jobs (id, employer_id, town_id, title, description, closing_date, created_by)
  values ('22222222-0000-0000-0000-000000000009', '11111111-0000-0000-0000-000000000001', 1,
          'Draft job', 'not ready', current_date + 30, :emp_1);
select test.reset();

select test.act_as(:emp_2);
insert into public.jobs (id, employer_id, town_id, title, description, closing_date, status, created_by)
  values ('22222222-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000002',
          (select id from public.towns where slug = 'standerton'), 'Cashier', 'Till and customer service',
          current_date + 7, 'pending_review', :emp_2);
select test.expect((select count(*) from public.jobs) = 1, 'employer 2 cannot see employer 1 unpublished jobs');
select test.reset();

select test.act_as(:admin);
update public.jobs set status = 'published' where status = 'pending_review';
select test.expect((select count(*) from public.jobs where published_at is not null) = 2, 'admin publishes jobs');
select test.reset();

select test.act_as_anon();
select test.expect((select count(*) from public.jobs) = 2, 'public sees published jobs only');
select test.expect((select count(*) from public.towns) >= 4, 'public sees towns');
select test.expect((select count(*) from public.applications) = 0, 'anon sees no applications');
select test.expect((select count(*) from public.profiles) = 0, 'anon sees no profiles');
select test.reset();

-- CVs and applications -----------------------------------------------------
select test.act_as(:seeker_a);
insert into public.candidate_cvs (id, candidate_id, content, pdf_path, is_primary)
  values ('33333333-0000-0000-0000-000000000001', :seeker_a, '{"skills":["milking"]}',
          'aaaaaaaa-0000-0000-0000-000000000001/33333333-0000-0000-0000-000000000001.pdf', true);
insert into storage.objects (bucket_id, name)
  values ('cvs', 'aaaaaaaa-0000-0000-0000-000000000001/33333333-0000-0000-0000-000000000001.pdf');
select test.expect_error($$insert into storage.objects (bucket_id, name) values ('cvs', 'aaaaaaaa-0000-0000-0000-000000000002/x.pdf')$$,
  'job seeker cannot upload into another user''s CV folder');
select test.expect_error($$insert into public.applications (job_id, candidate_id) values ('22222222-0000-0000-0000-000000000009', auth.uid())$$,
  'cannot apply to a draft job');
insert into public.applications (id, job_id, candidate_id, cv_id, status)
  values ('44444444-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001', :seeker_a,
          '33333333-0000-0000-0000-000000000001', 'hired');
select test.expect((select status from public.applications where id = '44444444-0000-0000-0000-000000000001') = 'submitted',
  'new applications always start as submitted');
select test.expect((select count(*) from public.notifications where type = 'application_received') = 1,
  'application received notification queued');
select test.reset();

select test.act_as(:seeker_b);
insert into public.candidate_cvs (id, candidate_id, pdf_path)
  values ('33333333-0000-0000-0000-000000000002', :seeker_b,
          'aaaaaaaa-0000-0000-0000-000000000002/33333333-0000-0000-0000-000000000002.pdf');
insert into storage.objects (bucket_id, name)
  values ('cvs', 'aaaaaaaa-0000-0000-0000-000000000002/33333333-0000-0000-0000-000000000002.pdf');
select test.expect_error($$insert into public.applications (job_id, candidate_id, cv_id)
  values ('22222222-0000-0000-0000-000000000002', auth.uid(), '33333333-0000-0000-0000-000000000001')$$,
  'cannot attach someone else''s CV');
insert into public.applications (id, job_id, candidate_id, cv_id)
  values ('44444444-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000002', :seeker_b,
          '33333333-0000-0000-0000-000000000002');
select test.expect((select count(*) from public.applications) = 1, 'candidate sees only own applications');
select test.expect((select count(*) from public.candidate_cvs) = 1, 'candidate sees only own CVs');
select test.reset();

-- Employer isolation (the core rule) --------------------------------------
select test.act_as(:emp_1);
select test.expect((select count(*) from public.applications) = 1, 'employer 1 sees only applications to own jobs');
select test.expect((select candidate_id from public.applications) = :seeker_a, 'employer 1 sees seeker A application');
select test.expect((select count(*) from public.profiles where role = 'job_seeker') = 1, 'employer 1 sees only applicant profiles');
select test.expect((select count(*) from public.candidate_profiles) = 1, 'employer 1 sees only applicant candidate profiles');
select test.expect((select count(*) from public.candidate_cvs) = 1, 'employer 1 sees only CVs sent to own jobs');
select test.expect((select count(*) from storage.objects) = 1, 'employer 1 can read only applicant CV files');
select test.expect(public.record_cv_access('44444444-0000-0000-0000-000000000001') like 'aaaaaaaa-0000-0000-0000-000000000001/%',
  'employer 1 can record CV access for own applicant');
select test.expect_error($$select public.record_cv_access('44444444-0000-0000-0000-000000000002')$$,
  'employer 1 cannot access CV sent to employer 2');
select test.expect((select count(*) from public.audit_logs) = 0, 'employers cannot read audit logs');
update public.applications set status = 'shortlisted' where id = '44444444-0000-0000-0000-000000000001';
update public.applications set status = 'shortlisted' where id = '44444444-0000-0000-0000-000000000002';
select test.expect_error($$update public.applications set cover_note = 'edited' where id = '44444444-0000-0000-0000-000000000001'$$,
  'employer cannot edit the candidate submission');
insert into public.application_notes (application_id, author_id, body)
  values ('44444444-0000-0000-0000-000000000001', :emp_1, 'Strong practical experience');
select test.reset();

select test.act_as(:emp_2);
select test.expect((select candidate_id from public.applications) = :seeker_b, 'employer 2 sees only seeker B');
select test.expect((select status from public.applications) = 'submitted', 'employer 1 could not change employer 2 application');
select test.expect((select count(*) from public.application_notes) = 0, 'employer 2 cannot read employer 1 notes');
select test.reset();

select test.act_as(:seeker_a);
select test.expect((select status from public.applications) = 'shortlisted', 'candidate sees status change');
select test.expect((select count(*) from public.application_status_history) = 2, 'status history recorded');
select test.expect((select count(*) from public.notifications where type = 'application_status_changed') = 1,
  'status change notification queued');
select test.expect((select count(*) from public.application_notes) = 0, 'candidate cannot read employer notes');
select test.expect_error($$update public.applications set status = 'hired'$$, 'candidate cannot hire themselves');
select test.expect_error($$update public.notifications set status = 'sent'$$, 'candidate cannot tamper with outbox');
update public.applications set status = 'withdrawn';
insert into public.consent_records (user_id, consent_type, granted, policy_version)
  values (:seeker_a, 'whatsapp_notifications', true, 'privacy-2026-11'),
         (:seeker_a, 'whatsapp_notifications', false, 'privacy-2026-11');
select test.expect((select granted from public.current_consents where consent_type = 'whatsapp_notifications') = false,
  'latest consent decision wins');
select test.expect_error($$delete from public.consent_records$$, 'consent history cannot be deleted');
select test.reset();

select test.act_as(:emp_1);
select test.expect((select count(*) from public.profiles where role = 'job_seeker') = 0,
  'withdrawn applicant profile is hidden from employer');
select test.expect((select count(*) from public.candidate_cvs) = 0, 'withdrawn applicant CV is hidden from employer');
select test.expect_error($$update public.applications set status = 'hired' where id = '44444444-0000-0000-0000-000000000001'$$,
  'employer cannot move a withdrawn application');
select test.reset();

select test.act_as(:admin);
select test.expect((select count(*) from public.audit_logs where action = 'cv.accessed') = 1, 'CV access is audited');
select test.expect((select count(*) from public.audit_logs where action = 'application.status_changed') = 2,
  'status changes are audited');
select test.reset();

\echo 'All RLS tests passed.'
