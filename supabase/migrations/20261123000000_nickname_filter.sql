-- SCOO: 닉네임 거르기 on the server too. Friends see the nickname, so it must follow the same rules as the app's
-- `NameFilter` (ios/SCOO/Models/NameFilter.swift) even when someone changes it without the app:
-- 1–12 characters, only complete Hangul, English letters, digits and spaces, not mostly digits or 4+ digits in a
-- row, and none of the blocked words (checked with spaces, digits and marks taken out, lowercase).
-- Keep the word list below in step with `NameFilter.blocked`.

create or replace function public.nickname_problem(p_name text) returns text
language sql immutable set search_path = public as $$
    select case
        when p_name is null or btrim(p_name) = '' then '이름을 한 글자 이상 지어 주세요.'
        when char_length(p_name) > 12 then '이름은 12글자까지 지을 수 있어요.'
        when p_name !~ '^[가-힣A-Za-z0-9 ]+$' then '한글(완성된 글자), 영어, 숫자, 띄어쓰기만 쓸 수 있어요.'
        when char_length(regexp_replace(p_name, '[^0-9]', '', 'g')) * 2 > char_length(p_name)
          or p_name ~ '[0-9]{4,}' then '숫자가 너무 많아요. 다른 이름으로 지어 주세요.'
        when lower(regexp_replace(p_name, '[^가-힣A-Za-z]', '', 'g')) like any (array[
        '%시발%', '%씨발%', '%씨바%', '%씨빨%', '%시빨%', '%쓰발%', '%쌍놈%', '%썅%', '%병신%', '%븅신%',
        '%빙신%', '%지랄%', '%개새%', '%개색%', '%새끼%', '%섀끼%', '%좆%', '%존나%', '%졸라%', '%니미%',
        '%느금%', '%애미%', '%애비%', '%엠창%', '%미친%', '%미췬%', '%닥쳐%', '%꺼져%', '%뒤져%', '%뒈져%',
        '%죽어%', '%죽일%', '%자살%', '%섹스%', '%쎅스%', '%섹시%', '%야동%', '%자지%', '%보지%', '%꼬추%',
        '%성기%', '%강간%', '%창녀%', '%창놈%', '%걸레%', '%화냥%', '%매춘%', '%원조교제%', '%한남충%', '%김치녀%',
        '%틀딱%', '%급식충%', '%맘충%', '%정신병%', '%변태%', '%노예%', '%마약%', '%대마%', '%필로폰%', '%운영자%',
        '%관리자%', '%fuck%', '%fck%', '%shit%', '%bitch%', '%sex%', '%porn%', '%dick%', '%cock%', '%pussy%',
        '%cunt%', '%nigg%', '%fag%', '%rape%', '%slut%', '%whore%', '%nazi%', '%hitler%'
        ]) then '쓸 수 없는 말이 들어 있어요. 다른 이름으로 지어 주세요.'
    end
$$;
revoke all on function public.nickname_problem(text) from public, anon;
grant execute on function public.nickname_problem(text) to authenticated;

-- Tidies the nickname (trimmed, single spaces) and refuses one that breaks the rules.
create or replace function public.check_nickname() returns trigger
language plpgsql set search_path = public as $$
declare
    problem text;
begin
    if new.nickname is null then return new; end if;
    new.nickname := regexp_replace(btrim(new.nickname), '\s+', ' ', 'g');
    problem := public.nickname_problem(new.nickname);
    if problem is not null then
        raise exception '%', problem using errcode = '22023';
    end if;
    return new;
end;
$$;

drop trigger if exists profiles_check_nickname on public.profiles;
create trigger profiles_check_nickname
    before insert or update of nickname on public.profiles
    for each row execute function public.check_nickname();
