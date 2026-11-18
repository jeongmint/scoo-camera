-- Minimal stand-in for Supabase Storage on plain PostgreSQL 16 (buckets, objects, foldername) for local tests.
create schema if not exists storage;
create table if not exists storage.buckets (
    id text primary key, name text, public boolean default false, file_size_limit bigint, allowed_mime_types text[]
);
create table if not exists storage.objects (
    id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets (id), name text,
    owner uuid default nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
);
create or replace function storage.foldername(name text) returns text[] language sql immutable as $$
    select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;
alter table storage.objects enable row level security;
grant usage on schema storage to authenticated, anon;
grant select, insert, delete on storage.objects to authenticated;
grant execute on function storage.foldername(text) to authenticated, anon;
