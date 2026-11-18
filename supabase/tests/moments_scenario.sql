-- Run after local_supabase_stubs.sql and the bottles + bottle_moments migrations (see README).
\set ON_ERROR_STOP off
insert into auth.users (id) values ('aaaaaaaa-0000-4000-8000-000000000001'), ('bbbbbbbb-0000-4000-8000-000000000002'), ('cccccccc-0000-4000-8000-000000000003');
-- A sends a baby asking for news, B sends one without; they swap
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select send_bottle('tori','sia','마포구',true,false) is not null as a_sent;
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select send_bottle('nyamo','dia','성동구',false,false) is not null as b_sent;
reset role; update bottles set arrives_at = now() - interval '1 second';
-- B has A's baby (news wanted) but has not opened it: nothing is shared
set role authenticated; set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select share_moment(array['cat','sky']) as b_before_open;
select open_bottle(id) as b_opened from my_bottles where direction = 'incoming';
select share_moment(array['cat','sky','cat','free text']) as b_shares;
select share_moment(array['cat']) as b_same_day_again;
select count(*) as b_reads_moments from bottle_moments;
insert into bottle_moments (bottle_id, subject) select id, 'dog' from bottles limit 1;
-- A opened B's baby, but B did not ask for news: A's words go nowhere
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select open_bottle(id) as a_opened from my_bottles where direction = 'incoming';
select share_moment(array['dog']) as a_shares;
select subject from bottle_moments order by subject;
-- C sees nothing
set request.jwt.claim.sub = 'cccccccc-0000-4000-8000-000000000003';
select count(*) as c_reads from bottle_moments;
select share_moment(array['cat']) as c_shares;
