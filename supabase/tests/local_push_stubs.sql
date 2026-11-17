-- Stand-ins for Supabase's vault and pg_net, so the push migration can run on plain PostgreSQL.
create schema if not exists vault;
create table if not exists vault.secrets (name text primary key, secret text);
create or replace view vault.decrypted_secrets as select name, secret as decrypted_secret from vault.secrets;
create or replace function vault.create_secret(p_secret text, p_name text) returns uuid language sql as $$
    insert into vault.secrets values (p_name, p_secret); select gen_random_uuid() $$;
create schema if not exists net;
create table if not exists net.sent (id serial, url text, headers jsonb, body jsonb);
create or replace function net.http_post(url text, headers jsonb, body jsonb) returns bigint language sql as $$
    insert into net.sent (url, headers, body) values (url, headers, body) returning id $$;
create schema if not exists extensions;
do $$ begin create role service_role nologin; exception when duplicate_object then null; end $$;
-- pg_net is not installable here: run the push migration without its `create extension` line.
