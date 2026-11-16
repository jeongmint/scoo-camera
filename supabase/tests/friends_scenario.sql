\set ON_ERROR_STOP off
\pset format unaligned
\pset fieldsep ' | '
insert into auth.users (id) values ('aaaaaaaa-0000-4000-8000-000000000001'), ('bbbbbbbb-0000-4000-8000-000000000002'), ('cccccccc-0000-4000-8000-000000000003');
set role authenticated;
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select 'A code', friend_code ~ '^[A-HJKMNP-Z2-9]{6}$' from my_profile();
update profiles set nickname = '에이', hero = 'nyamo' where id = auth.uid();
reset role; select friend_code as a_code from profiles where id = 'aaaaaaaa-0000-4000-8000-000000000001' \gset
set role authenticated; set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select 'B own code', request_friend((select friend_code from my_profile()));
select 'B unknown', request_friend('ZZZZZZ');
select 'B asks A', request_friend(lower(:'a_code'));
select 'B message before accept', send_message('aaaaaaaa-0000-4000-8000-000000000001', '안녕', null);
select 'B list', nickname, hero, status from list_friends();
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select 'A list', status from list_friends();
select 'A accepts', respond_friend('bbbbbbbb-0000-4000-8000-000000000002', true);
select 'A accepts twice', respond_friend('bbbbbbbb-0000-4000-8000-000000000002', true);
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select 'B sends', send_message('aaaaaaaa-0000-4000-8000-000000000001', '안녕! 오늘 바다 봤어', null) is not null;
select 'B sticker', send_message('aaaaaaaa-0000-4000-8000-000000000001', null, 'tori') is not null;
select 'B empty', send_message('aaaaaaaa-0000-4000-8000-000000000001', '  ', null);
select 'B asks A again', request_friend(:'a_code');
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select 'A list', status, last_sticker, unread from list_friends();
select 'A chat', mine, body, sticker from my_messages where friend_id = 'bbbbbbbb-0000-4000-8000-000000000002' order by created_at;
select 'A mark read', mark_read('bbbbbbbb-0000-4000-8000-000000000002');
select 'A list after read', unread from list_friends();
select 'A cannot set tester'; update profiles set is_tester = false where id = auth.uid();
set request.jwt.claim.sub = 'cccccccc-0000-4000-8000-000000000003';
select 'C sees messages', count(*) from my_messages;
select 'C sees friendships', count(*) from friendships;
select 'C reads A profile', count(*) from profiles where id = 'aaaaaaaa-0000-4000-8000-000000000001';
select 'C messages A', send_message('aaaaaaaa-0000-4000-8000-000000000001', 'hi', null);
reset role; set role anon;
select 'anon list', count(*) from list_friends();
