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

alter table public.event_registrations enable row level security;

revoke all on table public.event_registrations from anon, authenticated;
grant insert on table public.event_registrations to anon, authenticated;

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
