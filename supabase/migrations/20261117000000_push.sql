-- SCOO: push notifications.
-- Devices register their APNs token; triggers on letters, friend requests and bottle matches call the
-- `push` edge function through pg_net. The function and the triggers share a random secret kept in Vault,
-- so nobody else can make the function send pushes.

create extension if not exists pg_net with schema extensions;

create table if not exists public.push_tokens (
    user_id     uuid not null references auth.users (id) on delete cascade,
    token       text not null check (char_length(token) between 32 and 200),
    environment text not null check (environment in ('sandbox', 'production')),
    updated_at  timestamptz not null default now(),
    primary key (token)
);
create index if not exists push_tokens_user on public.push_tokens (user_id);
alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from anon, authenticated;

-- A device says where to reach it. One token belongs to one account at a time.
create or replace function public.register_push_token(p_token text, p_environment text) returns void
language plpgsql security definer set search_path = public as $$
begin
    if auth.uid() is null then raise exception 'not signed in'; end if;
    insert into public.push_tokens (user_id, token, environment) values (auth.uid(), lower(p_token), p_environment)
    on conflict (token) do update set user_id = excluded.user_id, environment = excluded.environment, updated_at = now();
end;
$$;
revoke all on function public.register_push_token(text, text) from public, anon;
grant execute on function public.register_push_token(text, text) to authenticated;

-- The shared secret, made once.
do $$
begin
    if not exists (select 1 from vault.secrets where name = 'push_hook_secret') then
        perform vault.create_secret(replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''), 'push_hook_secret');
    end if;
end $$;

-- Only the edge function (service role) may read it.
create or replace function public.push_hook_secret() returns text
language sql stable security definer set search_path = public as $$
    select decrypted_secret from vault.decrypted_secrets where name = 'push_hook_secret'
$$;
revoke all on function public.push_hook_secret() from public, anon, authenticated;
grant execute on function public.push_hook_secret() to service_role;

-- Queue a push for one account. Never blocks the write that caused it.
create or replace function public.queue_push(p_user uuid, p_title text, p_body text, p_kind text) returns void
language plpgsql security definer set search_path = public as $$
declare
    secret text;
begin
    select decrypted_secret into secret from vault.decrypted_secrets where name = 'push_hook_secret';
    if secret is null or p_user is null then return; end if;
    if not exists (select 1 from public.push_tokens where user_id = p_user) then return; end if;
    perform net.http_post(
        url := 'https://ofwexbasbwumfvswkixb.supabase.co/functions/v1/push',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', secret),
        body := jsonb_build_object('user_id', p_user, 'title', p_title, 'body', p_body, 'kind', p_kind)
    );
exception when others then
    raise warning 'push not queued: %', sqlerrm;
end;
$$;
revoke all on function public.queue_push(uuid, text, text, text) from public, anon, authenticated;

create or replace function public.display_name(p_user uuid) returns text
language sql stable security definer set search_path = public as $$
    select coalesce(nickname, '친구 ' || friend_code, '친구') from public.profiles where id = p_user
$$;
revoke all on function public.display_name(uuid) from public, anon, authenticated;

-- New letter → the receiver.
create or replace function public.push_on_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
    perform public.queue_push(new.receiver, '새 편지',
        public.display_name(new.sender) || case when new.body is null then ' 님이 스티커를 보냈어요' else ' 님에게서 편지가 왔어요' end,
        'message');
    return new;
end;
$$;
drop trigger if exists push_on_message on public.messages;
create trigger push_on_message after insert on public.messages for each row execute function public.push_on_message();

-- Friend request → the person asked; accepted → the person who asked.
create or replace function public.push_on_friendship() returns trigger
language plpgsql security definer set search_path = public as $$
begin
    if tg_op = 'INSERT' and not new.accepted then
        perform public.queue_push(new.addressee, '친구 요청', public.display_name(new.requester) || ' 님이 친구가 되고 싶어 해요', 'friend_request');
    elsif tg_op = 'UPDATE' and new.accepted and not old.accepted then
        perform public.queue_push(new.requester, '친구가 됐어요', public.display_name(new.addressee) || ' 님과 이제 편지를 주고받을 수 있어요', 'friend_accepted');
    end if;
    return new;
end;
$$;
drop trigger if exists push_on_friendship on public.friendships;
create trigger push_on_friendship after insert or update on public.friendships for each row execute function public.push_on_friendship();

-- A bottle finds its partner → its new receiver (the arrival itself is a local notification on the phone).
create or replace function public.push_on_bottle_match() returns trigger
language plpgsql security definer set search_path = public as $$
begin
    if old.receiver is null and new.receiver is not null then
        perform public.queue_push(new.receiver, '유리병', '바다 어딘가에서 유리병 하나가 떠내려오고 있어요', 'bottle');
    end if;
    return new;
end;
$$;
drop trigger if exists push_on_bottle_match on public.bottles;
create trigger push_on_bottle_match after update on public.bottles for each row execute function public.push_on_bottle_match();

revoke all on function public.push_on_message() from public, anon, authenticated;
revoke all on function public.push_on_friendship() from public, anon, authenticated;
revoke all on function public.push_on_bottle_match() from public, anon, authenticated;
