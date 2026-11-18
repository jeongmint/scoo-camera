-- SCOO: words for adopted babies' letters (입양 편지에 사진 대신 단어).
-- When the new family takes a photo, their phone sends only the photo's subject from a fixed list
-- (sky, cat, ...). The baby's letters to its first family use those words: "오늘 새 가족이랑 고양이를 봤어!".
-- No photo, no free text, so nothing unwanted can reach the other person.

create table if not exists public.bottle_moments (
    id          bigint generated always as identity primary key,
    bottle_id   uuid not null references public.bottles (id) on delete cascade,
    subject     text not null check (subject in ('sky','cat','flower','dog','green','sweet','sign','water','coffee','book','food')),
    day         date not null default (now() at time zone 'Asia/Seoul')::date,
    created_at  timestamptz not null default now(),
    unique (bottle_id, subject, day)
);
create index if not exists bottle_moments_bottle on public.bottle_moments (bottle_id, created_at);

alter table public.bottle_moments enable row level security;
revoke all on public.bottle_moments from anon, authenticated;
grant select on public.bottle_moments to authenticated;

-- Only the family that sent the baby away reads its words.
drop policy if exists "bottle_moments: sender reads" on public.bottle_moments;
create policy "bottle_moments: sender reads" on public.bottle_moments for select to authenticated
    using (exists (select 1 from public.bottles b where b.id = bottle_id and b.sender = (select auth.uid())));

-- The new family's phone shares today's photo subjects with every baby it adopted whose first family asked
-- for news. Each subject counts once per baby per day. Returns how many words were kept.
create or replace function public.share_moment(p_subjects text[]) returns integer
language plpgsql security definer set search_path = public as $$
declare
    me uuid := auth.uid();
    kept integer;
begin
    if me is null then raise exception 'not signed in'; end if;
    if coalesce(array_length(p_subjects, 1), 0) > 11 then raise exception 'too many subjects'; end if;
    insert into public.bottle_moments (bottle_id, subject)
    select b.id, s.subject
      from public.bottles b
      cross join (select distinct unnest(p_subjects) as subject) s
     where b.receiver = me and b.opened and b.wants_news
       and s.subject in ('sky','cat','flower','dog','green','sweet','sign','water','coffee','book','food')
    on conflict (bottle_id, subject, day) do nothing;
    get diagnostics kept = row_count;
    return kept;
end;
$$;
revoke all on function public.share_moment(text[]) from public, anon;
grant execute on function public.share_moment(text[]) to authenticated;
