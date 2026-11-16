-- SCOO: friends (by friend code) and letters between friends.
-- Everything goes through functions; tables are closed to direct writes.

-- ---------------------------------------------------------------------------
-- Profiles get a friend code and the character they show to friends.
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists friend_code text;
alter table public.profiles add column if not exists hero text;

create or replace function public.new_friend_code() returns text
language sql volatile set search_path = public as $$
    -- 6 characters without look-alikes (no 0/O, 1/I/L)
    select string_agg(substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 1 + floor(random() * 31)::int, 1), '')
    from generate_series(1, 6)
$$;

update public.profiles set friend_code = public.new_friend_code() where friend_code is null;
alter table public.profiles alter column friend_code set default public.new_friend_code();
create unique index if not exists profiles_friend_code on public.profiles (friend_code);

grant update (hero) on public.profiles to authenticated;
alter table public.profiles add constraint profiles_nickname_length check (nickname is null or char_length(nickname) between 1 and 12) not valid;
alter table public.profiles add constraint profiles_hero_length check (hero is null or char_length(hero) between 1 and 30) not valid;

-- ---------------------------------------------------------------------------
-- Friendships: one row per pair, requested by one side and accepted by the other.
-- ---------------------------------------------------------------------------
create table if not exists public.friendships (
    requester   uuid not null references auth.users (id) on delete cascade,
    addressee   uuid not null references auth.users (id) on delete cascade,
    accepted    boolean not null default false,
    created_at  timestamptz not null default now(),
    primary key (requester, addressee),
    check (requester <> addressee)
);
create index if not exists friendships_addressee on public.friendships (addressee);

alter table public.friendships enable row level security;
drop policy if exists "friendships: read mine" on public.friendships;
create policy "friendships: read mine" on public.friendships
    for select using (auth.uid() = requester or auth.uid() = addressee);
revoke insert, update, delete on public.friendships from authenticated, anon;

create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from public.friendships
         where accepted and ((requester = a and addressee = b) or (requester = b and addressee = a))
    )
$$;
revoke all on function public.are_friends(uuid, uuid) from public, anon, authenticated;

-- My code (creating the profile if the sign-up trigger somehow missed it).
create or replace function public.my_profile()
returns table (friend_code text, nickname text, hero text)
language plpgsql security definer set search_path = public as $$
begin
    if auth.uid() is null then raise exception 'not signed in'; end if;
    insert into public.profiles (id) values (auth.uid()) on conflict do nothing;
    return query select p.friend_code, p.nickname, p.hero from public.profiles p where p.id = auth.uid();
end;
$$;

-- Ask someone by their code. If they already asked me, we become friends right away.
-- Returns 'requested', 'friends' or 'already'.
create or replace function public.request_friend(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare
    me    uuid := auth.uid();
    them  uuid;
begin
    if me is null then raise exception 'not signed in'; end if;
    select id into them from public.profiles where friend_code = upper(trim(p_code));
    if them is null then raise exception 'no such code' using errcode = 'P0002'; end if;
    if them = me then raise exception 'that is your own code' using errcode = 'P0003'; end if;
    if public.are_friends(me, them) then return 'already'; end if;
    if exists (select 1 from public.friendships where requester = them and addressee = me) then
        update public.friendships set accepted = true where requester = them and addressee = me;
        return 'friends';
    end if;
    insert into public.friendships (requester, addressee) values (me, them) on conflict do nothing;
    return 'requested';
end;
$$;

-- Accept or turn down a request someone sent me.
create or replace function public.respond_friend(p_requester uuid, p_accept boolean) returns boolean
language plpgsql security definer set search_path = public as $$
declare changed integer;
begin
    if p_accept then
        update public.friendships set accepted = true where requester = p_requester and addressee = auth.uid() and not accepted;
    else
        delete from public.friendships where requester = p_requester and addressee = auth.uid() and not accepted;
    end if;
    get diagnostics changed = row_count;
    return changed = 1;
end;
$$;

-- ---------------------------------------------------------------------------
-- Letters between friends: a short text and/or a character sticker.
-- ---------------------------------------------------------------------------
create table if not exists public.messages (
    id          uuid primary key default gen_random_uuid(),
    sender      uuid not null references auth.users (id) on delete cascade,
    receiver    uuid not null references auth.users (id) on delete cascade,
    body        text check (body is null or char_length(body) between 1 and 500),
    sticker     text check (sticker is null or char_length(sticker) between 1 and 30),
    created_at  timestamptz not null default now(),
    read_at     timestamptz,
    check (body is not null or sticker is not null)
);
create index if not exists messages_pair_time on public.messages (sender, receiver, created_at);
create index if not exists messages_receiver_unread on public.messages (receiver) where read_at is null;

alter table public.messages enable row level security;
drop policy if exists "messages: read mine" on public.messages;
create policy "messages: read mine" on public.messages
    for select using (auth.uid() = sender or auth.uid() = receiver);
revoke insert, update, delete on public.messages from authenticated, anon;

create or replace function public.send_message(p_to uuid, p_body text, p_sticker text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
    me  uuid := auth.uid();
    new_id uuid;
    recent integer;
begin
    if me is null then raise exception 'not signed in'; end if;
    if not public.are_friends(me, p_to) then raise exception 'not friends' using errcode = 'P0004'; end if;
    select count(*) into recent from public.messages where sender = me and created_at > now() - interval '1 minute';
    if recent >= 30 then raise exception 'slow down' using errcode = 'P0005'; end if;
    insert into public.messages (sender, receiver, body, sticker)
    values (me, p_to, nullif(trim(p_body), ''), nullif(trim(p_sticker), ''))
    returning id into new_id;
    return new_id;
end;
$$;

create or replace function public.mark_read(p_friend uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare changed integer;
begin
    update public.messages set read_at = now() where receiver = auth.uid() and sender = p_friend and read_at is null;
    get diagnostics changed = row_count;
    return changed;
end;
$$;

-- Friends and requests with what the inbox needs: name, character, last letter, unread count.
create or replace function public.list_friends()
returns table (
    friend_id uuid, nickname text, friend_code text, hero text, status text,
    last_body text, last_sticker text, last_at timestamptz, unread integer
)
language sql stable security definer set search_path = public as $$
    with mine as (
        select case when f.requester = auth.uid() then f.addressee else f.requester end as other,
               case when f.accepted then 'friend'
                    when f.requester = auth.uid() then 'sent'
                    else 'received' end as status
          from public.friendships f
         where auth.uid() in (f.requester, f.addressee)
    )
    select m.other, p.nickname, p.friend_code, p.hero, m.status,
           last.body, last.sticker, last.created_at,
           (select count(*)::int from public.messages u where u.sender = m.other and u.receiver = auth.uid() and u.read_at is null)
      from mine m
      join public.profiles p on p.id = m.other
      left join lateral (
          select x.body, x.sticker, x.created_at from public.messages x
           where (x.sender = auth.uid() and x.receiver = m.other) or (x.sender = m.other and x.receiver = auth.uid())
           order by x.created_at desc limit 1
      ) last on true
     order by last.created_at desc nulls last, p.nickname
$$;

-- The conversation with one friend, oldest first.
create or replace view public.my_messages with (security_invoker = true) as
select id, case when sender = auth.uid() then receiver else sender end as friend_id,
       sender = auth.uid() as mine, body, sticker, created_at, read_at
  from public.messages
 where sender = auth.uid() or receiver = auth.uid();
grant select on public.my_messages to authenticated;

revoke all on function public.my_profile() from public, anon;
revoke all on function public.request_friend(text) from public, anon;
revoke all on function public.respond_friend(uuid, boolean) from public, anon;
revoke all on function public.send_message(uuid, text, text) from public, anon;
revoke all on function public.mark_read(uuid) from public, anon;
revoke all on function public.list_friends() from public, anon;
revoke all on function public.new_friend_code() from public, anon, authenticated;
grant execute on function public.my_profile() to authenticated;
grant execute on function public.request_friend(text) to authenticated;
grant execute on function public.respond_friend(uuid, boolean) to authenticated;
grant execute on function public.send_message(uuid, text, text) to authenticated;
grant execute on function public.mark_read(uuid) to authenticated;
grant execute on function public.list_friends() to authenticated;
