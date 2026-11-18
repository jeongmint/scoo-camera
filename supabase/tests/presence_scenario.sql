-- Run after the friends_scenario setup migrations + 20261118000200 and 20261118000300 (see friend_photos_scenario.sql).
\set ON_ERROR_STOP off
insert into auth.users (id) values ('aaaaaaaa-0000-4000-8000-000000000001'), ('bbbbbbbb-0000-4000-8000-000000000002'), ('cccccccc-0000-4000-8000-000000000003');
select friend_code as b_code from profiles where id = 'bbbbbbbb-0000-4000-8000-000000000002' \gset
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select request_friend(:'b_code') as a_asks;
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select respond_friend('aaaaaaaa-0000-4000-8000-000000000001', true) as b_accepts;
select share_presence(37.556789, 126.923456);
set request.jwt.claim.sub = 'cccccccc-0000-4000-8000-000000000003';
select share_presence(37.5, 126.9);
-- A sees B (rounded), not the stranger C
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select lat, lng from friends_nearby();
select count(*) as a_reads_table from friend_presence;
-- stale rows disappear
reset role; update friend_presence set updated_at = now() - interval '31 minutes' where user_id = 'bbbbbbbb-0000-4000-8000-000000000002';
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select count(*) as a_sees_after_30_min from friends_nearby();
-- B shares again, then blocks A: A no longer sees B
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select share_presence(37.556789, 126.923456);
select block_user('aaaaaaaa-0000-4000-8000-000000000001');
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select count(*) as a_sees_after_block from friends_nearby();
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select stop_presence();
reset role; select count(*) as rows_left_for_b from friend_presence where user_id = 'bbbbbbbb-0000-4000-8000-000000000002';
