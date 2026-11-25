-- Run after the stubs (local_supabase_stubs, local_push_stubs, local_storage_stubs) and every migration
-- (push without its `create extension` line). Expected results are in the comments.
\set ON_ERROR_STOP off
insert into auth.users (id) values ('aaaaaaaa-0000-4000-8000-000000000001'), ('bbbbbbbb-0000-4000-8000-000000000002'),
                                   ('cccccccc-0000-4000-8000-000000000003');
update profiles set is_tester = (id = 'cccccccc-0000-4000-8000-000000000003');   -- C is the operator
select friend_code as b_code from profiles where id = 'bbbbbbbb-0000-4000-8000-000000000002' \gset
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select request_friend(:'b_code') as a_asks;
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select respond_friend('aaaaaaaa-0000-4000-8000-000000000001', true) as b_accepts;
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
insert into storage.objects (bucket_id, name) values ('letters', 'aaaaaaaa-0000-4000-8000-000000000001/11111111-0000-4000-8000-000000000001.jpg');
select send_message('bbbbbbbb-0000-4000-8000-000000000002', '나쁜 말', null) is not null as a_sends_rude;
select send_message('bbbbbbbb-0000-4000-8000-000000000002', null, null, 'aaaaaaaa-0000-4000-8000-000000000001/11111111-0000-4000-8000-000000000001.jpg') is not null as a_sends_photo;
-- B reports both (without blocking)
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select report_message((select id from my_messages where body = '나쁜 말'), '욕을 했어요', false) as b_reports_words;      -- t
select report_message((select id from my_messages where photo is not null), '이상한 사진', false) as b_reports_photo;   -- t
-- not an operator: refused
select count(*) from review_reports();                                                                                -- ERROR operators only
select resolve_report(1, 'dismiss');                                                                                  -- ERROR operators only
select count(*) as b_sees_photo_before from storage.objects where bucket_id = 'letters';                               -- 1 (receiver)
-- C (operator) reviews
set request.jwt.claim.sub = 'cccccccc-0000-4000-8000-000000000003';
select reason, body, photo is not null as has_photo, reported_total, letter_exists from review_reports() order by id; -- 2 rows, total 2, exists t
select count(*) as c_sees_reported_photo from storage.objects where bucket_id = 'letters';                             -- 1
select min(id) as first_report, max(id) as last_report from review_reports() \gset
select resolve_report(:first_report, 'suspend', '욕설', 7) as c_suspends;                            -- t
select resolve_report(:last_report, 'dismiss') as c_dismisses_photo;                                -- t
select resolve_report(99999, 'dismiss') as missing;                                                                   -- f
select resolve_report(:last_report, 'explode') as bad_action;                                       -- ERROR unknown action
select count(*) as open_left from review_reports(true);                                                               -- 0
select status, body, letter_exists, suspended_until > now() + interval '6 days' as week from review_reports(false) order by id; -- suspended/나쁜 말/f/t, dismissed
-- A is suspended: cannot write or ask
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select send_message('bbbbbbbb-0000-4000-8000-000000000002', '왜?', null) as a_writes_suspended;                     -- ERROR suspended until
select count(*) as a_cannot_read_reports from reports;                                                                -- ERROR permission denied
update profiles set suspended_until = null where id = 'aaaaaaaa-0000-4000-8000-000000000001';                         -- ERROR permission
-- C lifts it, A can write again
set request.jwt.claim.sub = 'cccccccc-0000-4000-8000-000000000003';
select lift_suspension('aaaaaaaa-0000-4000-8000-000000000001');
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select send_message('bbbbbbbb-0000-4000-8000-000000000002', '미안해', null) is not null as a_writes_again;           -- t
reset role;
