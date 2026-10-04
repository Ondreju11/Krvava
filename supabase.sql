-- Opakování 20. 10. 2026 v 18:15 (Europe/Prague), kapacita 15.
-- Po naplnění kapacity se další přihlášky ukládají jako náhradníci (status = 'waitlist').
-- Spouštěj celý skript. Starší registrace zůstávají uložené pod původním event_slug.
begin;

create extension if not exists pgcrypto;
create extension if not exists citext with schema extensions;

create table if not exists public.event_registrations (
  id uuid primary key default gen_random_uuid(),
  event_slug text not null,
  full_name text not null check (char_length(trim(full_name)) between 2 and 120),
  email extensions.citext not null,
  source_url text,
  user_agent text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint event_registrations_email_format
    check (email::text ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$')
);

create unique index if not exists event_registrations_event_email_key
  on public.event_registrations (event_slug, email);

-- registered = má jisté místo, waitlist = náhradník (čeká na uvolněné místo).
-- Stávající registrace dostanou 'registered'.
alter table public.event_registrations
  add column if not exists status text not null default 'registered';

alter table public.event_registrations
  drop constraint if exists event_registrations_status_check;

alter table public.event_registrations
  add constraint event_registrations_status_check
  check (status in ('registered', 'waitlist'));

create index if not exists event_registrations_event_status_created_idx
  on public.event_registrations (event_slug, status, created_at, id);

create or replace function public.enforce_event_registration_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  registration_limit constant integer := 15;
  registration_count integer;
begin
  perform pg_advisory_xact_lock(hashtext(new.event_slug));

  if exists (
    select 1
    from public.event_registrations
    where event_slug = new.event_slug
      and email = new.email
  ) then
    return new;
  end if;

  select count(*)
    into registration_count
    from public.event_registrations
   where event_slug = new.event_slug
     and status = 'registered';

  -- Čas a stav určuje vždy databáze, ne klient. Čas se bere až po zámku,
  -- takže pořadí v created_at odpovídá skutečnému pořadí přihlášení.
  new.created_at := clock_timestamp();

  if registration_count >= registration_limit then
    new.status := 'waitlist';
  else
    new.status := 'registered';
  end if;

  return new;
end;
$$;

drop trigger if exists event_registration_limit_trigger on public.event_registrations;

create trigger event_registration_limit_trigger
  before insert on public.event_registrations
  for each row
  execute function public.enforce_event_registration_limit();

create or replace function public.get_event_registration_status(target_event_slug text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  registration_limit constant integer := 15;
  registered_count integer;
  waitlist_count integer;
begin
  if target_event_slug <> 'krvava-hodina-2026-10-20' then
    raise exception
      using
        errcode = 'P0001',
        message = 'EVENT_NOT_AVAILABLE';
  end if;

  select count(*) filter (where status = 'registered'),
         count(*) filter (where status = 'waitlist')
    into registered_count, waitlist_count
    from public.event_registrations
   where event_slug = target_event_slug;

  return jsonb_build_object(
    'event_slug', target_event_slug,
    'registration_limit', registration_limit,
    'registered_count', registered_count,
    'waitlist_count', waitlist_count,
    'remaining_spots', greatest(registration_limit - registered_count, 0),
    'is_full', registered_count >= registration_limit
  );
end;
$$;

-- Jediný vstup pro frontend: uloží přihlášku a vrátí, zda je hráč přihlášený,
-- nebo náhradník (a kolikátý v pořadí).
create or replace function public.register_for_event(
  target_event_slug text,
  full_name text,
  email text,
  source_url text default null,
  user_agent text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  inserted public.event_registrations%rowtype;
  waitlist_position integer;
begin
  if target_event_slug <> 'krvava-hodina-2026-10-20' then
    raise exception
      using
        errcode = 'P0001',
        message = 'EVENT_NOT_AVAILABLE';
  end if;

  insert into public.event_registrations (
    event_slug, full_name, email, source_url, user_agent
  )
  values (
    target_event_slug,
    trim(register_for_event.full_name),
    trim(register_for_event.email),
    left(register_for_event.source_url, 500),
    left(register_for_event.user_agent, 500)
  )
  returning * into inserted;

  if inserted.status = 'waitlist' then
    select count(*)
      into waitlist_position
      from public.event_registrations r
     where r.event_slug = inserted.event_slug
       and r.status = 'waitlist'
       and (r.created_at, r.id) <= (inserted.created_at, inserted.id);
  end if;

  return jsonb_build_object(
    'status', inserted.status,
    'waitlist_position', waitlist_position
  );
end;
$$;

-- Přehled pro pořadatele (Table Editor / SQL Editor): pořadí přihlášení
-- zvlášť pro přihlášené a pro náhradníky. Veřejný klient k němu nemá přístup.
create or replace view public.event_registration_order
with (security_invoker = true)
as
select
  event_slug,
  status,
  row_number() over (
    partition by event_slug, status
    order by created_at, id
  ) as poradi,
  full_name,
  email,
  created_at,
  id
from public.event_registrations
order by event_slug, status, created_at, id;

alter table public.event_registrations enable row level security;

revoke all on table public.event_registrations from anon, authenticated;
grant insert on table public.event_registrations to anon, authenticated;
grant execute on function public.get_event_registration_status(text) to anon, authenticated;
revoke all on function public.register_for_event(text, text, text, text, text) from public;
grant execute on function public.register_for_event(text, text, text, text, text) to anon, authenticated;
revoke all on table public.event_registration_order from anon, authenticated;

drop policy if exists "Public can insert event registrations" on public.event_registrations;

create policy "Public can insert event registrations"
  on public.event_registrations
  for insert
  to anon, authenticated
  with check (
    event_slug = 'krvava-hodina-2026-10-20'
    and char_length(trim(full_name)) between 2 and 120
    and email::text ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
  );

commit;
