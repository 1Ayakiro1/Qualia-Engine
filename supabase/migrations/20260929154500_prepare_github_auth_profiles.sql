-- Supabase Auth owns GitHub OAuth credentials and provider identities. Keep
-- only presentation fields in public.profiles and copy GitHub's public username
-- when a new Auth user is created.

alter table public.profiles
  add column username text
  check (username is null or length(username) <= 100);

create or replace function public.create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  profile_name text;
  profile_username text;
begin
  profile_username := coalesce(
    nullif(metadata ->> 'user_name', ''),
    nullif(metadata ->> 'preferred_username', '')
  );
  profile_name := coalesce(
    nullif(metadata ->> 'name', ''),
    nullif(metadata ->> 'full_name', ''),
    profile_username
  );

  insert into public.profiles (id, display_name, username, avatar_url)
  values (
    new.id,
    profile_name,
    profile_username,
    coalesce(nullif(metadata ->> 'avatar_url', ''), nullif(metadata ->> 'picture', ''))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- This is a trigger-only function; do not expose it as an RPC endpoint.
revoke execute on function public.create_profile_for_auth_user()
  from public, anon, authenticated;
