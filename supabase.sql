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
   where event_slug = new.event_slug;

  if registration_count >= registration_limit then
    raise exception
      using
        errcode = 'P0001',
        message = 'EVENT_FULL',
        detail = format(
          'Event %s already has %s registrations.',
          new.event_slug,
          registration_limit
        );
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
begin
  if target_event_slug <> 'krvava-hodina-2026-03-23' then
    raise exception
      using
        errcode = 'P0001',
        message = 'EVENT_NOT_AVAILABLE';
  end if;

  select count(*)
    into registered_count
    from public.event_registrations
   where event_slug = target_event_slug;

  return jsonb_build_object(
    'event_slug', target_event_slug,
    'registration_limit', registration_limit,
    'registered_count', registered_count,
    'remaining_spots', greatest(registration_limit - registered_count, 0),
    'is_full', registered_count >= registration_limit
  );
end;
$$;

alter table public.event_registrations enable row level security;

revoke all on table public.event_registrations from anon, authenticated;
grant insert on table public.event_registrations to anon, authenticated;
grant execute on function public.get_event_registration_status(text) to anon, authenticated;

drop policy if exists "Public can insert event registrations" on public.event_registrations;

create policy "Public can insert event registrations"
  on public.event_registrations
  for insert
  to anon, authenticated
  with check (
    event_slug = 'krvava-hodina-2026-03-23'
    and char_length(trim(full_name)) between 2 and 120
    and email::text ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
  );
