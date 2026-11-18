-- SCOO: delete my account (App Store requires it for apps that create accounts).
-- Everything of mine goes with auth.users (profiles, friendships, letters, push tokens, counts cascade).
-- Bottles I sent that already reached someone stay with them: the sender becomes empty instead of the row
-- disappearing, so nobody loses a baby they were given. Bottles still waiting at sea are removed.

alter table public.bottles alter column sender drop not null;
alter table public.bottles drop constraint if exists bottles_sender_fkey;
alter table public.bottles add constraint bottles_sender_fkey
    foreign key (sender) references auth.users (id) on delete set null;

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare
    me uuid := auth.uid();
begin
    if me is null then raise exception 'not signed in'; end if;
    delete from public.bottles where sender = me and receiver is null;
    delete from auth.users where id = me;
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
