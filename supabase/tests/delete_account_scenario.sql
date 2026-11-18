-- Run after local_supabase_stubs.sql and the bottles, friends, moments and delete_account migrations.
\set ON_ERROR_STOP off
insert into auth.users (id) values ('aaaaaaaa-0000-4000-8000-000000000001'), ('bbbbbbbb-0000-4000-8000-000000000002');
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select send_bottle('tori','sia','마포구',true,false) is not null as a_sent_matched;
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select send_bottle('nyamo','dia','성동구',true,false) is not null as b_sent;
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select send_bottle('mori','kuru','마포구',false,false) is not null as a_sent_waiting;
reset role;
select count(*) as bottles_before from bottles;
set role anon; set request.jwt.claim.sub = '';
select delete_my_account();
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select delete_my_account();
reset role;
select count(*) as a_gone from auth.users where id = 'aaaaaaaa-0000-4000-8000-000000000001';
select count(*) as bottles_after, count(*) filter (where sender is null) as kept_for_b from bottles;
select count(*) as friendships_left from friendships;
set role authenticated; set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select direction, parent_a from my_bottles order by direction;
