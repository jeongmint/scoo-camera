-- SCOO: 운영자 모드. Only operator accounts (profiles.is_tester) may send many bottles a day and use the
-- one-minute delivery; the app shows its test menu only to them. New accounts are ordinary from now on.
-- Which account is an operator is data, set by hand in the SQL Editor, never in a migration:
--   update public.profiles set is_tester = true where id = '<account id>';

alter table public.profiles alter column is_tester set default false;

create or replace function public.am_i_operator() returns boolean
language sql stable security definer set search_path = public as $$
    select coalesce((select is_tester from public.profiles where id = auth.uid()), false)
$$;
revoke all on function public.am_i_operator() from public, anon;
grant execute on function public.am_i_operator() to authenticated;
