-- SCOO: random names follow the current cast (야구공 is now 츄츄, and the new characters join).
-- Only the function changes; names people already have stay.

create or replace function public.new_nickname() returns text
language sql volatile set search_path = public as $$
    select (array['졸린','포근한','반짝이는','수줍은','용감한','느긋한','말랑한','씩씩한','상냥한',
                  '새침한','엉뚱한','다정한','보송한','통통한','꼬마','신난','조용한','배고픈'])[1 + floor(random() * 18)::int]
        || ' ' ||
           (array['귀요','쿠르','모리','냐모','후우','치코','도치','루나','토토','써니','수리','멜루','리루','포포','귤','츄츄','수달','실타래','토리','무푸','더기','헤치','시아','디아','코미','멜로','반디','루미','보송','치루','크로','잉키','모모','무무','피코','포실','로라'])[1 + floor(random() * 37)::int]
$$;
revoke all on function public.new_nickname() from public, anon, authenticated;
