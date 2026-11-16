-- The sign-up trigger function is not part of the API: only the trigger runs it.
-- (Security advisor 0028/0029. send_bottle and open_bottle stay callable by signed-in users on purpose.)
revoke execute on function public.handle_new_user() from public, anon, authenticated;
