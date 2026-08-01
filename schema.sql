-- ============================================================================
-- Unassigned — database schema (Supabase / PostgreSQL)
-- Run once: Supabase Dashboard -> SQL Editor -> New query -> paste all -> Run.
-- ============================================================================

-- Every signed-up user gets a permanent anonymous username like ASSIGNED123ABC.
-- The recipient only ever sees this username, never the real person.
create table if not exists public.users (
  id           uuid primary key default gen_random_uuid(),
  username     text unique not null,              -- e.g. ASSIGNED123ABC
  phone        text unique,                       -- the user's own phone (optional)
  api_token    text unique not null,              -- how this user authenticates sends
  tier         text not null default 'free'
               check (tier in ('free','plus','group','pro')),
  created_at   timestamptz not null default now()
);

-- Consent per recipient phone. No link is delivered unless status = 'opted_in'.
create table if not exists public.consent_registry (
  phone_number text primary key,                  -- E.164, e.g. +15165550100
  status       text not null default 'pending'
               check (status in ('pending','opted_in','opted_out')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Links held server-side until the recipient replies Y. Carries the sender's
-- USERNAME only (never their identity).
create table if not exists public.held_links (
  id             uuid primary key default gen_random_uuid(),
  phone_number   text not null references public.consent_registry(phone_number) on delete cascade,
  from_username  text not null,
  link_url       text not null,
  note           text,
  created_at     timestamptz not null default now()
);

-- Daily send counter for tier limits.
create table if not exists public.send_counts (
  username   text not null,
  day        date not null default current_date,
  count      int  not null default 0,
  primary key (username, day)
);

create index if not exists idx_held_phone on public.held_links(phone_number);

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end; $$;

drop trigger if exists trg_consent_touch on public.consent_registry;
create trigger trg_consent_touch before update on public.consent_registry
  for each row execute function public.touch_updated_at();

-- Lock tables to server (service-role) access only.
alter table public.users            enable row level security;
alter table public.consent_registry enable row level security;
alter table public.held_links       enable row level security;
alter table public.send_counts      enable row level security;

-- ----------------------------------------------------------------------------
-- Atomic daily-send counter. Increments and returns the new count in ONE
-- statement, eliminating the read-then-write race. Returns the count AFTER
-- incrementing; the caller checks it against the tier limit.
-- ----------------------------------------------------------------------------
create or replace function public.bump_send_count(p_username text, p_limit int)
returns table(allowed boolean, new_count int)
language plpgsql as $$
declare
  current_count int;
begin
  insert into public.send_counts (username, day, count)
    values (p_username, current_date, 0)
  on conflict (username, day) do nothing;

  -- lock the row, read, decide, and increment atomically
  select count into current_count
    from public.send_counts
    where username = p_username and day = current_date
    for update;

  if current_count >= p_limit then
    return query select false, current_count;
  else
    update public.send_counts
      set count = count + 1
      where username = p_username and day = current_date;
    return query select true, current_count + 1;
  end if;
end;
$$;
