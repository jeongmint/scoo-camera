-- Breed art made by the breed-image edge function.
-- One PNG per ordered pair (parent A shape, parent B color) in a public bucket, shared by everyone.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('breeds', 'breeds', true, 5242880, array['image/png'])
on conflict (id) do nothing;

-- Who asked for which new picture, for the daily limit. Only the edge function (service role) touches it.
create table if not exists public.breed_generations (
    id          bigint generated always as identity primary key,
    user_id     uuid not null references auth.users (id) on delete cascade,
    pair        text not null,
    created_at  timestamptz not null default now()
);

create index if not exists breed_generations_user_time on public.breed_generations (user_id, created_at);

alter table public.breed_generations enable row level security;
revoke all on public.breed_generations from anon, authenticated;
