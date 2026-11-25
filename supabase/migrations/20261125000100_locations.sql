-- WORKLINK: South African location reference data.
-- Province -> municipality -> town. Read-only for everyone; only admins (service role) change it.

create table public.provinces (
  id smallint generated always as identity primary key,
  code text not null unique,          -- e.g. 'MP'
  name text not null unique
);

create table public.municipalities (
  id integer generated always as identity primary key,
  province_id smallint not null references public.provinces (id),
  code text unique,                    -- MDB code, e.g. 'MP305'
  name text not null,
  kind text not null check (kind in ('metropolitan', 'district', 'local')),
  unique (province_id, name)
);

create table public.towns (
  id integer generated always as identity primary key,
  municipality_id integer not null references public.municipalities (id),
  name text not null,
  slug text not null unique,
  unique (municipality_id, name)
);

create index towns_municipality_idx on public.towns (municipality_id);
create index municipalities_province_idx on public.municipalities (province_id);

alter table public.provinces enable row level security;
alter table public.municipalities enable row level security;
alter table public.towns enable row level security;

create policy "Locations are public" on public.provinces for select using (true);
create policy "Locations are public" on public.municipalities for select using (true);
create policy "Locations are public" on public.towns for select using (true);

insert into public.provinces (code, name) values
  ('EC', 'Eastern Cape'),
  ('FS', 'Free State'),
  ('GP', 'Gauteng'),
  ('KZN', 'KwaZulu-Natal'),
  ('LP', 'Limpopo'),
  ('MP', 'Mpumalanga'),
  ('NC', 'Northern Cape'),
  ('NW', 'North West'),
  ('WC', 'Western Cape');

-- Launch area: Lekwa Local Municipality (Gert Sibande District), Mpumalanga.
insert into public.municipalities (province_id, code, name, kind)
select id, 'MP305', 'Lekwa Local Municipality', 'local' from public.provinces where code = 'MP';

insert into public.towns (municipality_id, name, slug)
select m.id, t.name, t.slug
from public.municipalities m
cross join (values
  ('Standerton', 'standerton'),
  ('Sakhile', 'sakhile'),
  ('Morgenzon', 'morgenzon'),
  ('Thuthukani', 'thuthukani')
) as t(name, slug)
where m.code = 'MP305';
