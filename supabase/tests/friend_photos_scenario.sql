-- Run after local_supabase_stubs.sql, local_push_stubs.sql, local_storage_stubs.sql, the accounts, friends and
-- push migrations (push without its `create extension` line) and 20261118000200_friend_photos_and_blocks.sql.
\set ON_ERROR_STOP off
insert into auth.users (id) values ('aaaaaaaa-0000-4000-8000-000000000001'), ('bbbbbbbb-0000-4000-8000-000000000002'), ('cccccccc-0000-4000-8000-000000000003');
select friend_code as b_code from profiles where id = 'bbbbbbbb-0000-4000-8000-000000000002' \gset
-- A and B become friends
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select request_friend(:'b_code') as a_asks;
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select respond_friend('aaaaaaaa-0000-4000-8000-000000000001', true) as b_accepts;
-- A uploads into their own folder (allowed) and into B's (refused)
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
insert into storage.objects (bucket_id, name) values ('letters', 'aaaaaaaa-0000-4000-8000-000000000001/11111111-0000-4000-8000-000000000001.jpg');
insert into storage.objects (bucket_id, name) values ('letters', 'bbbbbbbb-0000-4000-8000-000000000002/11111111-0000-4000-8000-000000000002.jpg');
select send_message('bbbbbbbb-0000-4000-8000-000000000002', null, null, 'aaaaaaaa-0000-4000-8000-000000000001/11111111-0000-4000-8000-000000000001.jpg') is not null as a_sends_photo;
select send_message('bbbbbbbb-0000-4000-8000-000000000002', null, null, 'aaaaaaaa-0000-4000-8000-000000000001/99999999-0000-4000-8000-000000000009.jpg') as a_sends_missing_photo;
select send_message('bbbbbbbb-0000-4000-8000-000000000002', '안녕', null) is not null as a_sends_text_old_call;
select last_photo, last_body from list_friends();
-- B sees the photo, C does not
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select count(*) as b_sees_photo from storage.objects where bucket_id = 'letters';
select count(*) filter (where photo is not null) as b_photo_letters from my_messages;
set request.jwt.claim.sub = 'cccccccc-0000-4000-8000-000000000003';
select count(*) as c_sees_photo from storage.objects where bucket_id = 'letters';
select send_message('bbbbbbbb-0000-4000-8000-000000000002', '모르는 사람', null) as c_not_friends;
-- B reports the photo letter and blocks A
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select report_message((select id from my_messages where photo is not null), '이상한 사진', true) as b_reports_and_blocks;
select count(*) as b_sees_photo_after_block from storage.objects where bucket_id = 'letters';
select nickname is not null as has_name from my_blocks();
select count(*) as b_friends_after from list_friends();
-- A can no longer write or ask again
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select send_message('bbbbbbbb-0000-4000-8000-000000000002', '왜?', null) as a_after_block;
select request_friend(:'b_code') as a_asks_again;
select count(*) as a_reads_reports from reports;
reset role;
select reason, photo is not null as kept_photo from reports;
-- B unblocks
set role authenticated; set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select unblock_user('aaaaaaaa-0000-4000-8000-000000000001');
select count(*) as b_blocks_after_unblock from my_blocks();
