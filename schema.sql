-- Unassigned - database schema
-- Reconstructed on 2026-09-15 by reading the live Supabase project
-- (information_schema + pg_get_functiondef). The live database is the
-- authoritative copy; this file exists so the schema can be rebuilt.

create table if not exists public.users (
  id         uuid        not null default gen_random_uuid() primary key,
  username   text        not null unique,          -- ASSIGNED + 6 alphanumerics
  phone      text,
  api_token  text        not null unique,
  tier       text        not null default 'free',  -- free | plus | group | pro
  created_at timestamptz not null default now()
);

create table if not exists public.consent_registry (
  phone_number text        not null primary key,   -- E.164
  status       text        not null default 'pending', -- pending | opted_in | opted_out
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.held_links (
  id            uuid        not null default gen_random_uuid() primary key,
  phone_number  text        not null,
  from_username text        not null,
  link_url      text        not null,
  note          text,
  created_at    timestamptz not null default now()
);

create index if not exists held_links_phone_idx on public.held_links (phone_number);

create table if not exists public.send_counts (
  username text not null,
  day      date not null default current_date,
  count    integer not null default 0,
  primary key (username, day)
);

-- Daily send limit. Returns whether the send is allowed and the new count.
-- Called by seal-and-send via supabase.rpc('bump_send_count', {...}).
create or replace function public.bump_send_count(p_username text, p_limit integer)
returns table(allowed boolean, new_count integer)
language plpgsql
as $function$
declare
  current_count int;
begin
  insert into public.send_counts (username, day, count)
  values (p_username, current_date, 0)
  on conflict (username, day) do nothing;

  select count into current_count
  from public.send_counts
  where username = p_username and day = current_date
  for update;

  if current_count >= p_limit then
    return query select false, current_count;
  else
    update public.send_counts set count = count + 1
    where username = p_username and day = current_date;
    return query select true, current_count + 1;
  end if;
end;
$function$;
