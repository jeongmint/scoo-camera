-- Run after local_supabase_stubs.sql, the accounts migrations, 20261118000100_delete_account and 20261118000400_bottle_settle.
\set ON_ERROR_STOP off
insert into auth.users (id) values ('aaaaaaaa-0000-4000-8000-000000000001'), ('bbbbbbbb-0000-4000-8000-000000000002'), ('cccccccc-0000-4000-8000-000000000003');
-- A sends a character; nobody else is at sea
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select send_bottle('mori','mori','서울 마포구',true,false) is not null as a_sent;
select settle_bottle(id) as a_settles_too_early from my_bottles where direction = 'outgoing';
reset role; update bottles set sent_at = now() - interval '25 hours';
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select settle_bottle(id) as a_settles_next_day from my_bottles where direction = 'outgoing';
select settle_bottle(id) as a_settles_twice from my_bottles where direction = 'outgoing';
select direction, settled from my_bottles;
-- B sends: adopts A's (settled) bottle one way; B's own bottle waits, already settled (B's return is A's bottle)
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select send_bottle('dia','dia','경북 청송군',false,false) is not null as b_sent;
select direction, parent_a, settled, arrives_at is not null as coming from my_bottles order by direction;
select settle_bottle(id) as b_cannot_settle from my_bottles where direction = 'outgoing';
-- C sends: adopts B's settled bottle one way, C waits (settled)
set request.jwt.claim.sub = 'cccccccc-0000-4000-8000-000000000003';
select send_bottle('kuru','kuru','부산 해운대구',false,false) is not null as c_sent;
select direction, parent_a, settled from my_bottles order by direction;
-- A was not given anything more
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select count(*) filter (where direction = 'incoming') as a_incoming from my_bottles;
