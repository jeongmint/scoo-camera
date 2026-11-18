-- SCOO: 펫과 음성 대화 (pet-chat edge function). Counts replies per account per day for the daily limit.
-- Only the edge function (service role) touches it; the words themselves are never stored.
create table if not exists public.pet_talk_usage (
    user_id  uuid not null references auth.users (id) on delete cascade,
    day      date not null default (now() at time zone 'Asia/Seoul')::date,
    replies  integer not null default 0,
    primary key (user_id, day)
);
alter table public.pet_talk_usage enable row level security;
revoke all on public.pet_talk_usage from anon, authenticated;

-- One more reply for this account today; returns the new count. Service role only.
create or replace function public.count_pet_reply(p_user uuid) returns integer
language sql security definer set search_path = public as $$
    insert into public.pet_talk_usage as u (user_id, day, replies)
    values (p_user, (now() at time zone 'Asia/Seoul')::date, 1)
    on conflict (user_id, day) do update set replies = u.replies + 1
    returning replies
$$;
revoke all on function public.count_pet_reply(uuid) from public, anon, authenticated;
grant execute on function public.count_pet_reply(uuid) to service_role;
