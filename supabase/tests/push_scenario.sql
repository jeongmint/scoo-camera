\set ON_ERROR_STOP off
\pset format unaligned
\pset fieldsep ' | '
insert into auth.users (id) values ('aaaaaaaa-0000-4000-8000-000000000001'), ('bbbbbbbb-0000-4000-8000-000000000002');
update profiles set nickname = '에이' where id = 'aaaaaaaa-0000-4000-8000-000000000001';
select friend_code as a_code from profiles where id = 'aaaaaaaa-0000-4000-8000-000000000001' \gset
set role authenticated;
set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select 'A registers', register_push_token('ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789', 'sandbox');
select 'A reads tokens'; select count(*) from push_tokens;
set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select 'B registers', register_push_token('11112222333344445555666677778888999900001111222233334444555566667777', 'production');
select 'B asks A', request_friend(:'a_code');
reset role;
select 'queued after request', body->>'user_id' = 'aaaaaaaa-0000-4000-8000-000000000001', body->>'body', headers ? 'x-push-secret' from net.sent order by id;
set role authenticated; set request.jwt.claim.sub = 'aaaaaaaa-0000-4000-8000-000000000001';
select 'A accepts', respond_friend('bbbbbbbb-0000-4000-8000-000000000002', true);
select 'A writes', send_message('bbbbbbbb-0000-4000-8000-000000000002', '안녕', null) is not null;
select 'A sticker', send_message('bbbbbbbb-0000-4000-8000-000000000002', null, 'tori') is not null;
reset role;
select 'all queued', body->>'kind', body->>'title', body->>'body' from net.sent order by id;
select 'secret readable by service only'; set role authenticated; select push_hook_secret(); reset role;
select 'token moves to the account that registers it last';
set role authenticated; set request.jwt.claim.sub = 'bbbbbbbb-0000-4000-8000-000000000002';
select register_push_token('abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789', 'sandbox');
reset role; select user_id, environment from push_tokens order by token;
