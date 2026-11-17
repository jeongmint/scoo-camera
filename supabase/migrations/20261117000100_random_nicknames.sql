-- SCOO: every account starts with a friendly random name ("졸린 모리"), so nobody has to type one
-- and logins (Kakao, Google, Apple) never need to share a profile name.

create or replace function public.new_nickname() returns text
language sql volatile set search_path = public as $$
    select (array['졸린','포근한','반짝이는','수줍은','용감한','느긋한','말랑한','씩씩한','상냥한',
                  '새침한','엉뚱한','다정한','보송한','통통한','꼬마','신난','조용한','배고픈'])[1 + floor(random() * 18)::int]
        || ' ' ||
           (array['귀요','쿠르','모리','냐모','후우','치코','도치','루나','토토','써니','수리','멜루',
                  '리루','포포','귤','야구공','수달','실타래','토리','무푸','더기','헤치','시아','디아'])[1 + floor(random() * 24)::int]
$$;

revoke all on function public.new_nickname() from public, anon, authenticated;

alter table public.profiles alter column nickname set default public.new_nickname();
update public.profiles set nickname = public.new_nickname() where nickname is null;

-- Letters and pushes fall back to the friend code only if a name was cleared on purpose.
