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
