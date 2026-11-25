-- SCOO: 익명 가입 남용 막기. Anyone can make a new anonymous account, so per-account limits alone do not protect
-- the paid AI calls or friend codes. This adds:
--   * a cap for everyone together per day on talk replies (checked before the model is called, so nothing is
--     spent over it), next to the per-account cap; the breed-image function caps new pictures the same way;
--   * a daily limit on friend-code tries per account, counting codes that do not exist (no guessing codes).

-- Totals per day across all accounts, by kind ('pet_reply').
create table if not exists public.daily_totals (
    kind   text not null,
    day    date not null,
    total  integer not null default 0,
    primary key (kind, day)
);
alter table public.daily_totals enable row level security;
revoke all on public.daily_totals from anon, authenticated;

-- One talk reply for this account, if neither its own cap nor everyone's cap for today is reached.
-- 'ok' (counted), 'mine' (this account is at its cap) or 'everyone' (the day's total is reached).
create or replace function public.take_pet_reply(p_user uuid, p_limit integer, p_everyone integer) returns text
language plpgsql security definer set search_path = public as $$
declare
    today    date := (now() at time zone 'Asia/Seoul')::date;
    mine     integer;
    everyone integer;
begin
    select replies into mine from public.pet_talk_usage where user_id = p_user and day = today;
    if coalesce(mine, 0) >= p_limit then return 'mine'; end if;
    insert into public.daily_totals as t (kind, day, total) values ('pet_reply', today, 1)
    on conflict (kind, day) do update set total = t.total + 1
    returning total into everyone;
    if everyone > p_everyone then
        update public.daily_totals set total = total - 1 where kind = 'pet_reply' and day = today;
        return 'everyone';
    end if;
    perform public.count_pet_reply(p_user);
    return 'ok';
end;
$$;
revoke all on function public.take_pet_reply(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.take_pet_reply(uuid, integer, integer) to service_role;

-- Friend-code tries per account per day (found or not).
create table if not exists public.friend_code_tries (
    user_id uuid not null references auth.users (id) on delete cascade,
    day     date not null,
    tries   integer not null default 0,
    primary key (user_id, day)
);
alter table public.friend_code_tries enable row level security;
revoke all on public.friend_code_tries from anon, authenticated;

-- Same as before, except: every try is counted (30 a day, operators excepted), and a code that does not exist
-- now returns 'not_found' instead of raising, so the counted try is kept. Blocked people still look like a code
-- that does not exist.
create or replace function public.request_friend(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare
    me    uuid := auth.uid();
    them  uuid;
    attempts integer;
begin
    if me is null then raise exception 'not signed in'; end if;
    insert into public.friend_code_tries as t (user_id, day, tries)
    values (me, (now() at time zone 'Asia/Seoul')::date, 1)
    on conflict (user_id, day) do update set tries = t.tries + 1
    returning t.tries into attempts;
    if attempts > 30 and not public.am_i_operator() then
        raise exception 'too many tries' using errcode = 'P0006';
    end if;
    select id into them from public.profiles where friend_code = upper(trim(p_code));
    if them is null or public.is_blocked(me, them) then return 'not_found'; end if;
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
