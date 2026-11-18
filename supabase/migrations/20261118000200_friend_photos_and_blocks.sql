-- SCOO: photos in letters between friends, and report / block.
-- Photos travel only between friends: the sender uploads to the private `letters` bucket under their own
-- folder, and only the sender and the receiver of a letter that carries the photo can read it.
-- Blocking ends the friendship and stops letters and friend requests both ways; a report keeps a record for
-- review (service role only).

-- ---------------------------------------------------------------------------
-- Blocks and reports
-- ---------------------------------------------------------------------------
create table if not exists public.blocks (
    blocker     uuid not null references auth.users (id) on delete cascade,
    blocked     uuid not null references auth.users (id) on delete cascade,
    created_at  timestamptz not null default now(),
    primary key (blocker, blocked),
    check (blocker <> blocked)
);
alter table public.blocks enable row level security;
revoke all on public.blocks from anon, authenticated;
grant select on public.blocks to authenticated;
drop policy if exists "blocks: read mine" on public.blocks;
create policy "blocks: read mine" on public.blocks for select to authenticated using (blocker = (select auth.uid()));

create table if not exists public.reports (
    id          bigint generated always as identity primary key,
    reporter    uuid references auth.users (id) on delete set null,
    reported    uuid references auth.users (id) on delete set null,
    message_id  uuid,
    photo       text,
    reason      text check (reason is null or char_length(reason) <= 300),
    created_at  timestamptz not null default now()
);
alter table public.reports enable row level security;
revoke all on public.reports from anon, authenticated;

create or replace function public.is_blocked(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
    select exists (select 1 from public.blocks where (blocker = a and blocked = b) or (blocker = b and blocked = a))
$$;
revoke all on function public.is_blocked(uuid, uuid) from public, anon, authenticated;

create or replace function public.block_user(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
    if me is null then raise exception 'not signed in'; end if;
    if p_user is null or p_user = me then return; end if;
    insert into public.blocks (blocker, blocked) values (me, p_user) on conflict do nothing;
    delete from public.friendships where (requester = me and addressee = p_user) or (requester = p_user and addressee = me);
end;
$$;

create or replace function public.unblock_user(p_user uuid) returns void
language sql security definer set search_path = public as $$
    delete from public.blocks where blocker = auth.uid() and blocked = p_user
$$;

-- Report a letter I received (its words, sticker or photo). `p_block` also blocks the sender.
create or replace function public.report_message(p_message uuid, p_reason text, p_block boolean) returns boolean
language plpgsql security definer set search_path = public as $$
declare
    me uuid := auth.uid();
    letter public.messages%rowtype;
begin
    if me is null then raise exception 'not signed in'; end if;
    select * into letter from public.messages where id = p_message and receiver = me;
    if not found then return false; end if;
    insert into public.reports (reporter, reported, message_id, photo, reason)
    values (me, letter.sender, letter.id, letter.photo, left(nullif(trim(p_reason), ''), 300));
    if p_block then perform public.block_user(letter.sender); end if;
    return true;
end;
$$;

-- People I blocked, to unblock them from settings.
create or replace function public.my_blocks()
returns table (user_id uuid, nickname text, blocked_at timestamptz)
language sql stable security definer set search_path = public as $$
    select b.blocked, p.nickname, b.created_at
      from public.blocks b left join public.profiles p on p.id = b.blocked
     where b.blocker = auth.uid()
     order by b.created_at desc
$$;

-- Friend requests between blocked people fail as if the code did not exist (no hint that a block exists).
create or replace function public.request_friend(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare
    me    uuid := auth.uid();
    them  uuid;
begin
    if me is null then raise exception 'not signed in'; end if;
    select id into them from public.profiles where friend_code = upper(trim(p_code));
    if them is null or public.is_blocked(me, them) then raise exception 'no such code' using errcode = 'P0002'; end if;
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

-- ---------------------------------------------------------------------------
-- Photos in letters
-- ---------------------------------------------------------------------------
alter table public.messages add column if not exists photo text
    check (photo is null or photo ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$');
alter table public.messages drop constraint if exists messages_check;
alter table public.messages drop constraint if exists messages_has_content;
alter table public.messages add constraint messages_has_content
    check (body is not null or sticker is not null or photo is not null);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('letters', 'letters', false, 2097152, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = 2097152, allowed_mime_types = array['image/jpeg'];

-- Upload only into my own folder.
drop policy if exists "letters: upload own" on storage.objects;
create policy "letters: upload own" on storage.objects for insert to authenticated
    with check (bucket_id = 'letters' and (storage.foldername(name))[1] = (select auth.uid())::text);
-- Whether a letter photo was sent to me by someone neither of us has blocked (without exposing blocks).
create or replace function public.letter_photo_for_me(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
    select exists (select 1 from public.messages m
                    where m.photo = p_name and m.receiver = auth.uid()
                      and not public.is_blocked(m.sender, m.receiver))
$$;
revoke all on function public.letter_photo_for_me(text) from public, anon;
grant execute on function public.letter_photo_for_me(text) to authenticated;

-- Read my own uploads, or a photo in a letter sent to me by someone I have not blocked.
drop policy if exists "letters: read sent or received" on storage.objects;
create policy "letters: read sent or received" on storage.objects for select to authenticated
    using (bucket_id = 'letters' and (
        (storage.foldername(name))[1] = (select auth.uid())::text
        or public.letter_photo_for_me(name)
    ));
drop policy if exists "letters: delete own" on storage.objects;
create policy "letters: delete own" on storage.objects for delete to authenticated
    using (bucket_id = 'letters' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop function if exists public.send_message(uuid, text, text);
create or replace function public.send_message(p_to uuid, p_body text, p_sticker text, p_photo text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
    me  uuid := auth.uid();
    new_id uuid;
    recent integer;
    photos integer;
begin
    if me is null then raise exception 'not signed in'; end if;
    if not public.are_friends(me, p_to) or public.is_blocked(me, p_to) then
        raise exception 'not friends' using errcode = 'P0004';
    end if;
    select count(*) into recent from public.messages where sender = me and created_at > now() - interval '1 minute';
    if recent >= 30 then raise exception 'slow down' using errcode = 'P0005'; end if;
    if p_photo is not null then
        -- the photo must be mine and already uploaded
        if split_part(p_photo, '/', 1) <> me::text
           or not exists (select 1 from storage.objects where bucket_id = 'letters' and name = p_photo) then
            raise exception 'photo not found' using errcode = 'P0006';
        end if;
        select count(*) into photos from public.messages
         where sender = me and photo is not null and created_at > now() - interval '1 day';
        if photos >= 50 then raise exception 'photo limit reached' using errcode = 'P0007'; end if;
    end if;
    insert into public.messages (sender, receiver, body, sticker, photo)
    values (me, p_to, nullif(trim(p_body), ''), nullif(trim(p_sticker), ''), p_photo)
    returning id into new_id;
    return new_id;
end;
$$;

create or replace view public.my_messages with (security_invoker = true) as
select id, case when sender = auth.uid() then receiver else sender end as friend_id,
       sender = auth.uid() as mine, body, sticker, created_at, read_at, photo
  from public.messages
 where sender = auth.uid() or receiver = auth.uid();
grant select on public.my_messages to authenticated;

drop function if exists public.list_friends();
create or replace function public.list_friends()
returns table (
    friend_id uuid, nickname text, friend_code text, hero text, status text,
    last_body text, last_sticker text, last_at timestamptz, unread integer, last_photo boolean
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
           (select count(*)::int from public.messages u where u.sender = m.other and u.receiver = auth.uid() and u.read_at is null),
           last.photo is not null
      from mine m
      join public.profiles p on p.id = m.other
      left join lateral (
          select x.body, x.sticker, x.photo, x.created_at from public.messages x
           where (x.sender = auth.uid() and x.receiver = m.other) or (x.sender = m.other and x.receiver = auth.uid())
           order by x.created_at desc limit 1
      ) last on true
     order by last.created_at desc nulls last, p.nickname
$$;

-- A photo letter's push says so.
create or replace function public.push_on_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
    perform public.queue_push(new.receiver, '새 편지',
        public.display_name(new.sender) || case
            when new.photo is not null then ' 님이 사진을 보냈어요'
            when new.body is null then ' 님이 스티커를 보냈어요'
            else ' 님에게서 편지가 왔어요' end,
        'message');
    return new;
end;
$$;
revoke all on function public.push_on_message() from public, anon, authenticated;

revoke all on function public.block_user(uuid) from public, anon;
revoke all on function public.unblock_user(uuid) from public, anon;
revoke all on function public.report_message(uuid, text, boolean) from public, anon;
revoke all on function public.my_blocks() from public, anon;
revoke all on function public.request_friend(text) from public, anon;
revoke all on function public.send_message(uuid, text, text, text) from public, anon;
revoke all on function public.list_friends() from public, anon;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.report_message(uuid, text, boolean) to authenticated;
grant execute on function public.my_blocks() to authenticated;
grant execute on function public.request_friend(text) to authenticated;
grant execute on function public.send_message(uuid, text, text, text) to authenticated;
grant execute on function public.list_friends() to authenticated;
