\set ON_ERROR_STOP off
insert into auth.users (id) values ('aaaaaaaa-0000-4000-8000-000000000001'), ('bbbbbbbb-0000-4000-8000-000000000002'), ('cccccccc-0000-4000-8000-000000000003');
select count(*) as profiles_created from public.profiles;
-- A sends twice (tester)
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select send_bottle('tori','sia','마포구',true,false) is not null as a_sent_1;
select send_bottle('mori','kuru','마포구',false,false) is not null as a_sent_2;
select direction, parent_a, arrives_at is null as waiting from my_bottles order by sent_at;
-- B sends: should swap with A's oldest
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select send_bottle('nyamo','dia','성동구',true,true) is not null as b_sent;
select direction, parent_a, origin, (arrives_at - matched_at) as travel from my_bottles order by direction;
select open_bottle(id) as b_open_early from my_bottles where direction = 'incoming';
insert into bottles (sender, parent_a, parent_b, origin) values (auth.uid(), 'x','y','z');
update profiles set is_tester = false where id = auth.uid();
update profiles set nickname = '비비' where id = auth.uid();
select count(*) as b_sees_rows_in_bottles from bottles;
reset role;
update bottles set arrives_at = now() - interval '1 second' where receiver = 'bbbbbbbb-0000-4000-8000-000000000002';
set role authenticated; set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select open_bottle(id) as b_open_after_arrival from my_bottles where direction = 'incoming';
select open_bottle(id) as b_open_twice from my_bottles where direction = 'incoming';
-- A now sees the swap
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select direction, parent_a, origin, receiver_known from (select *, arrives_at is not null as receiver_known from my_bottles) t order by sent_at;
-- C is not a tester: one bottle a day
reset role; update profiles set is_tester = false where id = 'cccccccc-0000-4000-8000-000000000003';
set role authenticated; set request.jwt.claim.sub = 'cccccccc-0000-4000-8000-000000000003';
select send_bottle('gwiyo','mori','강남구',false,true) is not null as c_sent_1;
select direction, (arrives_at - matched_at) as c_travel_fast_ignored from my_bottles;
select send_bottle('gwiyo','mori','강남구',false,false) as c_sent_2;
select count(*) as c_sees from my_bottles;
-- signed out
reset role; set role anon; select send_bottle('a','b','c',false,false);
