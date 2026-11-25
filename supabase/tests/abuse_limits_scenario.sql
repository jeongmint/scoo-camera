-- Run after the stubs and every migration (see report_review_scenario.sql). Expected results in comments.
\set ON_ERROR_STOP off
insert into auth.users (id) values ('aaaaaaaa-0000-4000-8000-000000000001'), ('bbbbbbbb-0000-4000-8000-000000000002');
update profiles set is_tester = false;
select friend_code as b_code from profiles where id = 'bbbbbbbb-0000-4000-8000-000000000002' \gset
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select request_friend('ZZZZZZ') as wrong_code;                                             -- not_found (no error)
select count(*) from (select request_friend('ZZZZZ' || n) from generate_series(1, 28) n) t;  -- 28 more tries
select request_friend(:'b_code') as thirtieth_try_still_works;                            -- requested
select request_friend('YYYYYY') as thirty_first;                                          -- ERROR too many tries
select request_friend(:'b_code') as still_blocked_today;                                  -- ERROR too many tries
select count(*) from friend_code_tries;                                                   -- ERROR permission denied
reset role;
select tries from friend_code_tries;                                                      -- 30
-- talk replies: one account's cap, then everyone's cap
select take_pet_reply('aaaaaaaa-0000-4000-8000-000000000001', 2, 3) as r1,                -- ok
       take_pet_reply('aaaaaaaa-0000-4000-8000-000000000001', 2, 3) as r2,                -- ok
       take_pet_reply('aaaaaaaa-0000-4000-8000-000000000001', 2, 3) as r3;                -- mine
select take_pet_reply('bbbbbbbb-0000-4000-8000-000000000002', 2, 3) as b1,                -- ok
       take_pet_reply('bbbbbbbb-0000-4000-8000-000000000002', 2, 3) as b2;                -- everyone
select total from daily_totals where kind = 'pet_reply';                                  -- 3
select sum(replies) from pet_talk_usage;                                                  -- 3
set role authenticated;
select take_pet_reply('aaaaaaaa-0000-4000-8000-000000000001', 100, 100);                  -- ERROR permission denied
reset role;
