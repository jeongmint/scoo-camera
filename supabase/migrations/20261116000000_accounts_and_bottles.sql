-- SCOO: accounts and glass-bottle adoption.
-- Run once in the Supabase SQL editor (or `supabase db push`).
-- Users sign in anonymously from the app; every table is protected by row level security.

-- ---------------------------------------------------------------------------
-- Profiles: one row per account, created on first sign-in.
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
    id          uuid primary key references auth.users (id) on delete cascade,
    nickname    text,
    district    text,                       -- the Seoul district the user started in
    is_tester   boolean not null default true,  -- testers may send more bottles and use fast delivery
    created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own" on public.profiles
    for select using (auth.uid() = id);

drop policy if exists "profiles: update own" on public.profiles;
create policy "profiles: update own" on public.profiles
    for update using (auth.uid() = id) with check (auth.uid() = id);

-- New accounts (anonymous included) get a profile automatically.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    insert into public.profiles (id) values (new.id) on conflict do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- Users may change their nickname and district, nothing else (testers cannot promote themselves).
revoke insert, update, delete on public.profiles from authenticated, anon;
grant update (nickname, district) on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- Bottles: a baby (two parent species) travelling from one user to another.
-- A bottle waits at sea (receiver is null) until someone else sends one; then the two are swapped.
-- ---------------------------------------------------------------------------
create table if not exists public.bottles (
    id          uuid primary key default gen_random_uuid(),
    sender      uuid not null references auth.users (id) on delete cascade,
    receiver    uuid references auth.users (id) on delete set null,
    parent_a    text not null check (char_length(parent_a) between 1 and 40),
    parent_b    text not null check (char_length(parent_b) between 1 and 40),
    origin      text not null check (char_length(origin) between 1 and 40),
    wants_news  boolean not null default false,
    sent_at     timestamptz not null default now(),
    matched_at  timestamptz,
    arrives_at  timestamptz,
    opened      boolean not null default false
);

create index if not exists bottles_waiting on public.bottles (sent_at) where receiver is null;
create index if not exists bottles_sender on public.bottles (sender);
create index if not exists bottles_receiver on public.bottles (receiver);

alter table public.bottles enable row level security;

-- You see bottles you sent and bottles coming to you. Nobody sees who else is involved.
drop policy if exists "bottles: read mine" on public.bottles;
create policy "bottles: read mine" on public.bottles
    for select using (auth.uid() = sender or auth.uid() = receiver);

-- No direct writes: everything goes through the functions below.
revoke insert, update, delete on public.bottles from authenticated, anon;

-- What the app reads: the other person's id is never returned.
create or replace view public.my_bottles with (security_invoker = true) as
select
    id,
    case when sender = auth.uid() then 'outgoing' else 'incoming' end as direction,
    parent_a, parent_b, origin, wants_news, sent_at, matched_at, arrives_at, opened
from public.bottles
where sender = auth.uid() or receiver = auth.uid();

grant select on public.my_bottles to authenticated;

-- Send a baby. If another user's bottle is waiting at sea, the two bottles swap owners and both
-- set off now; otherwise this one waits for the next sender. Returns the new bottle's id.
create or replace function public.send_bottle(
    p_parent_a text, p_parent_b text, p_origin text, p_wants_news boolean, p_fast boolean default false
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
    me          uuid := auth.uid();
    tester      boolean;
    sent_today  integer;
    travel      interval;
    mine        uuid;
    partner     public.bottles%rowtype;
begin
    if me is null then raise exception 'not signed in'; end if;
    select coalesce(is_tester, false) into tester from public.profiles where id = me;

    select count(*) into sent_today from public.bottles
     where sender = me and sent_at >= date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
    if sent_today >= (case when tester then 50 else 1 end) then
        raise exception 'daily limit reached' using errcode = 'P0001';
    end if;

    travel := case when p_fast and tester then interval '1 minute' else interval '1 day' end;

    insert into public.bottles (sender, parent_a, parent_b, origin, wants_news)
    values (me, p_parent_a, p_parent_b, p_origin, p_wants_news)
    returning id into mine;

    -- the oldest bottle someone else left at sea
    select * into partner from public.bottles
     where receiver is null and sender <> me and id <> mine
     order by sent_at
     limit 1
     for update skip locked;

    if found then
        update public.bottles set receiver = me, matched_at = now(), arrives_at = now() + travel where id = partner.id;
        update public.bottles set receiver = partner.sender, matched_at = now(), arrives_at = now() + travel where id = mine;
    end if;

    return mine;
end;
$$;

-- Open a bottle that has arrived for you. Returns false if it is not yours, not here yet, or already open.
create or replace function public.open_bottle(p_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
    changed integer;
begin
    update public.bottles set opened = true
     where id = p_id and receiver = auth.uid() and not opened and arrives_at <= now();
    get diagnostics changed = row_count;
    return changed = 1;
end;
$$;

revoke all on function public.send_bottle(text, text, text, boolean, boolean) from public, anon;
revoke all on function public.open_bottle(uuid) from public, anon;
grant execute on function public.send_bottle(text, text, text, boolean, boolean) to authenticated;
grant execute on function public.open_bottle(uuid) to authenticated;
