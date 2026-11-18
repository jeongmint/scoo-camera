-- 아직 서버에 적용되지 않은 변경 다섯 개를 순서대로 묶은 파일이에요.
-- Supabase 대시보드 → SQL Editor에 통째로 붙여 넣고 Run 하면 돼요.
-- (supabase/migrations 의 000100 ~ 000500 과 같은 내용, 한 번에 실패하면 전부 되돌아가요.)

begin;

-- ===== 20261118000100_delete_account =====
-- SCOO: delete my account (App Store requires it for apps that create accounts).
-- Everything of mine goes with auth.users (profiles, friendships, letters, push tokens, counts cascade).
-- Bottles I sent that already reached someone stay with them: the sender becomes empty instead of the row
-- disappearing, so nobody loses a baby they were given. Bottles still waiting at sea are removed.

alter table public.bottles alter column sender drop not null;
alter table public.bottles drop constraint if exists bottles_sender_fkey;
alter table public.bottles add constraint bottles_sender_fkey
    foreign key (sender) references auth.users (id) on delete set null;

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare
    me uuid := auth.uid();
begin
    if me is null then raise exception 'not signed in'; end if;
    delete from public.bottles where sender = me and receiver is null;
    delete from auth.users where id = me;
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;


-- ===== 20261118000200_friend_photos_and_blocks =====
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


-- ===== 20261118000300_friend_presence =====
-- SCOO: friends nearby (주변 친구 거리). Off unless the user turns it on in the camera.
-- Only friends see it, the position is rounded to about 100 m, and it disappears 30 minutes after the
-- last update (the app also removes it when the user turns it off or leaves the camera).

create table if not exists public.friend_presence (
    user_id     uuid primary key references auth.users (id) on delete cascade,
    lat         double precision not null check (lat between -90 and 90),
    lng         double precision not null check (lng between -180 and 180),
    updated_at  timestamptz not null default now()
);
alter table public.friend_presence enable row level security;
revoke all on public.friend_presence from anon, authenticated;

create or replace function public.share_presence(p_lat double precision, p_lng double precision) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
    if me is null then raise exception 'not signed in'; end if;
    insert into public.friend_presence (user_id, lat, lng, updated_at)
    values (me, round(p_lat::numeric, 3)::double precision, round(p_lng::numeric, 3)::double precision, now())
    on conflict (user_id) do update set lat = excluded.lat, lng = excluded.lng, updated_at = now();
    -- tidy up everyone's stale rows now and then
    delete from public.friend_presence where updated_at < now() - interval '30 minutes';
end;
$$;

create or replace function public.stop_presence() returns void
language sql security definer set search_path = public as $$
    delete from public.friend_presence where user_id = auth.uid()
$$;

-- Friends who shared in the last 30 minutes (accepted, not blocked), with their rounded position.
create or replace function public.friends_nearby()
returns table (friend_id uuid, nickname text, hero text, lat double precision, lng double precision, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
    select p.user_id, pr.nickname, pr.hero, p.lat, p.lng, p.updated_at
      from public.friend_presence p
      join public.profiles pr on pr.id = p.user_id
     where p.user_id <> auth.uid()
       and p.updated_at > now() - interval '30 minutes'
       and public.are_friends(auth.uid(), p.user_id)
       and not public.is_blocked(auth.uid(), p.user_id)
$$;

revoke all on function public.share_presence(double precision, double precision) from public, anon;
revoke all on function public.stop_presence() from public, anon;
revoke all on function public.friends_nearby() from public, anon;
grant execute on function public.share_presence(double precision, double precision) to authenticated;
grant execute on function public.stop_presence() to authenticated;
grant execute on function public.friends_nearby() to authenticated;


-- ===== 20261118000400_bottle_settle =====
-- SCOO: adoption reworked (입양 재정비). Any character can travel, once a day.
-- The day after sending, the sender gets exactly one thing back: the bottle of whoever it was swapped with,
-- or, if nobody came, a random new character from the sea (made on the phone after `settle_bottle`).
-- `settled` marks a bottle whose sender already got their one thing back; it still waits at sea for someone
-- to adopt it, and that adoption is then one way (the adopter keeps their own bottle waiting).

alter table public.bottles add column if not exists settled boolean not null default false;

create or replace view public.my_bottles with (security_invoker = true) as
select
    id,
    case when sender = auth.uid() then 'outgoing' else 'incoming' end as direction,
    parent_a, parent_b, origin, wants_news, sent_at, matched_at, arrives_at, opened,
    (sender = auth.uid() and settled) as settled
from public.bottles
where sender = auth.uid() or receiver = auth.uid();
grant select on public.my_bottles to authenticated;

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
     where receiver is null and (sender is null or sender <> me) and id <> mine
     order by sent_at
     limit 1
     for update skip locked;

    if found then
        update public.bottles set receiver = me, matched_at = now(), arrives_at = now() + travel where id = partner.id;
        if partner.settled or partner.sender is null then
            -- its sender already got something back: I adopt it, and my bottle keeps waiting for someone,
            -- already settled because my one thing back is this bottle
            update public.bottles set settled = true where id = mine;
        else
            update public.bottles set receiver = partner.sender, matched_at = now(), arrives_at = now() + travel where id = mine;
        end if;
    end if;

    return mine;
end;
$$;

-- Nobody came for my bottle in time: the sea brings me a new character instead (the phone picks it).
-- True only once per bottle, and only when it is due.
create or replace function public.settle_bottle(p_id uuid, p_fast boolean default false) returns boolean
language plpgsql security definer set search_path = public as $$
declare
    me uuid := auth.uid();
    tester boolean;
    travel interval;
    changed integer;
begin
    if me is null then raise exception 'not signed in'; end if;
    select coalesce(is_tester, false) into tester from public.profiles where id = me;
    travel := case when p_fast and tester then interval '1 minute' else interval '1 day' end;
    update public.bottles set settled = true
     where id = p_id and sender = me and receiver is null and not settled and sent_at <= now() - travel;
    get diagnostics changed = row_count;
    return changed = 1;
end;
$$;

revoke all on function public.settle_bottle(uuid, boolean) from public, anon;
grant execute on function public.settle_bottle(uuid, boolean) to authenticated;


-- ===== 20261118000500_nickname_names =====
-- SCOO: random names follow the current cast (야구공 is now 도도, and the new characters join).
-- Only the function changes; names people already have stay.

create or replace function public.new_nickname() returns text
language sql volatile set search_path = public as $$
    select (array['졸린','포근한','반짝이는','수줍은','용감한','느긋한','말랑한','씩씩한','상냥한',
                  '새침한','엉뚱한','다정한','보송한','통통한','꼬마','신난','조용한','배고픈'])[1 + floor(random() * 18)::int]
        || ' ' ||
           (array['귀요','쿠르','모리','냐모','후우','치코','도치','루나','토토','써니','수리','멜루','리루','포포','귤','도도','수달','실타래','토리','무푸','더기','헤치','시아','디아','코미','멜로','반디','루미','보송','치루','크로','잉키','모모','무무','피코','포실','로라'])[1 + floor(random() * 37)::int]
$$;
revoke all on function public.new_nickname() from public, anon, authenticated;


-- 적용 기록 (나중에 Supabase CLI로 다시 적용하지 않도록)
insert into supabase_migrations.schema_migrations (version, name) values
  ('20261118000100','delete_account'),('20261118000200','friend_photos_and_blocks'),
  ('20261118000300','friend_presence'),('20261118000400','bottle_settle'),('20261118000500','nickname_names')
on conflict do nothing;

commit;

-- (선택) 시험용 익명 계정 지우기. 필요하면 아래 줄 앞의 -- 를 지우고 한 번 더 Run.
-- delete from auth.users where id = '6407c8ee-cb37-4c17-8ab2-6bedf0295d15' and is_anonymous;
