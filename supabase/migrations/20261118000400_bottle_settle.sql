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
