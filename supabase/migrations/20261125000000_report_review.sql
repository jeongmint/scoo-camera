-- SCOO: 신고 처리. Operators (profiles.is_tester, see 20261119000000_operator_mode) review reported letters in the
-- app: leave it (문제 없음), remove the letter (편지 지우기), or remove it and stop the sender from writing letters and
-- asking for friends for a while (보내기 정지). Everything here checks `am_i_operator()` itself.

-- A report keeps the letter's words, so it can still be reviewed after the letter is removed.
alter table public.reports add column if not exists body text;
alter table public.reports add column if not exists sticker text;
alter table public.reports add column if not exists status text not null default 'open';
alter table public.reports add column if not exists action_note text;
alter table public.reports add column if not exists reviewed_by uuid references auth.users (id) on delete set null;
alter table public.reports add column if not exists reviewed_at timestamptz;
do $$ begin
    alter table public.reports add constraint reports_status_check
        check (status in ('open', 'dismissed', 'removed', 'suspended'));
exception when duplicate_object then null; end $$;
create index if not exists reports_open on public.reports (created_at desc) where status = 'open';
create index if not exists reports_reported on public.reports (reported);

-- Until when someone may not send letters or friend requests. Only operators set it (users can update
-- nickname and district only).
alter table public.profiles add column if not exists suspended_until timestamptz;

create or replace function public.report_message(p_message uuid, p_reason text, p_block boolean) returns boolean
language plpgsql security definer set search_path = public as $$
declare
    me uuid := auth.uid();
    letter public.messages%rowtype;
begin
    if me is null then raise exception 'not signed in'; end if;
    select * into letter from public.messages where id = p_message and receiver = me;
    if not found then return false; end if;
    insert into public.reports (reporter, reported, message_id, photo, body, sticker, reason)
    values (me, letter.sender, letter.id, letter.photo, letter.body, letter.sticker, left(nullif(trim(p_reason), ''), 300));
    if p_block then perform public.block_user(letter.sender); end if;
    return true;
end;
$$;

-- A suspended sender cannot write letters or ask anyone to be friends.
create or replace function public.check_not_suspended() returns trigger
language plpgsql security definer set search_path = public as $$
declare
    who uuid;
    stop timestamptz;
begin
    -- (a record field cannot be named for a table that lacks it, so pick per table)
    if tg_table_name = 'messages' then who := new.sender; else who := new.requester; end if;
    select suspended_until into stop from public.profiles where id = who;
    if stop is not null and stop > now() then
        raise exception 'suspended until %', to_char(stop at time zone 'Asia/Seoul', 'YYYY-MM-DD') using errcode = 'P0001';
    end if;
    return new;
end;
$$;
revoke all on function public.check_not_suspended() from public, anon, authenticated;

drop trigger if exists messages_not_suspended on public.messages;
create trigger messages_not_suspended before insert on public.messages
    for each row execute function public.check_not_suspended();
drop trigger if exists friendships_not_suspended on public.friendships;
create trigger friendships_not_suspended before insert on public.friendships
    for each row execute function public.check_not_suspended();

-- Reports for operators: open ones (p_open) or the ones already handled, newest first.
create or replace function public.review_reports(p_open boolean default true)
returns table (id bigint, created_at timestamptz, reason text, status text, action_note text, reviewed_at timestamptz,
               reporter_name text, reported uuid, reported_name text, reported_total bigint, suspended_until timestamptz,
               message_id uuid, body text, sticker text, photo text, letter_exists boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
    if not public.am_i_operator() then raise exception 'operators only' using errcode = '42501'; end if;
    return query
    select r.id, r.created_at, r.reason, r.status, r.action_note, r.reviewed_at,
           pr.nickname, r.reported, pd.nickname,
           (select count(*) from public.reports x where x.reported = r.reported),
           pd.suspended_until, r.message_id,
           coalesce(r.body, m.body), coalesce(r.sticker, m.sticker), r.photo, m.id is not null
      from public.reports r
      left join public.profiles pr on pr.id = r.reporter
      left join public.profiles pd on pd.id = r.reported
      left join public.messages m on m.id = r.message_id
     where (p_open and r.status = 'open') or (not p_open and r.status <> 'open')
     order by r.created_at desc
     limit 200;
end;
$$;

-- Handles one report: 'dismiss', 'remove' (deletes the letter) or 'suspend' (deletes it and stops the sender for
-- p_days). Other open reports of the same letter are closed with it. False when the report does not exist.
create or replace function public.resolve_report(p_id bigint, p_action text, p_note text default null, p_days int default 7)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
    rep public.reports%rowtype;
    outcome text;
begin
    if not public.am_i_operator() then raise exception 'operators only' using errcode = '42501'; end if;
    outcome := case p_action when 'dismiss' then 'dismissed' when 'remove' then 'removed' when 'suspend' then 'suspended' end;
    if outcome is null then raise exception 'unknown action' using errcode = '22023'; end if;
    select * into rep from public.reports where id = p_id for update;
    if not found then return false; end if;
    if p_action in ('remove', 'suspend') and rep.message_id is not null then
        delete from public.messages where id = rep.message_id;
    end if;
    if p_action = 'suspend' and rep.reported is not null then
        update public.profiles
           set suspended_until = greatest(coalesce(suspended_until, now()), now())
                                 + make_interval(days => greatest(1, least(coalesce(p_days, 7), 365)))
         where id = rep.reported;
    end if;
    update public.reports
       set status = outcome, action_note = left(nullif(trim(p_note), ''), 300), reviewed_by = auth.uid(), reviewed_at = now()
     where id = p_id
        or (rep.message_id is not null and message_id = rep.message_id and status = 'open');
    return true;
end;
$$;

-- Lets someone write again before the suspension ends.
create or replace function public.lift_suspension(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
    if not public.am_i_operator() then raise exception 'operators only' using errcode = '42501'; end if;
    update public.profiles set suspended_until = null where id = p_user;
end;
$$;

revoke all on function public.review_reports(boolean) from public, anon;
revoke all on function public.resolve_report(bigint, text, text, int) from public, anon;
revoke all on function public.lift_suspension(uuid) from public, anon;
grant execute on function public.review_reports(boolean) to authenticated;
grant execute on function public.resolve_report(bigint, text, text, int) to authenticated;
grant execute on function public.lift_suspension(uuid) to authenticated;

-- Operators may look at a reported letter photo (only the sender and the receiver can otherwise).
create or replace function public.is_reported_photo(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
    select exists (select 1 from public.reports where photo = p_name)
$$;
revoke all on function public.is_reported_photo(text) from public, anon;
grant execute on function public.is_reported_photo(text) to authenticated;

drop policy if exists "letters: operators read reported" on storage.objects;
create policy "letters: operators read reported" on storage.objects for select to authenticated
    using (bucket_id = 'letters' and public.am_i_operator() and public.is_reported_photo(name));
