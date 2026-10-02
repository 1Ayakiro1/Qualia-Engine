-- Supabase Auth owns credentials and OAuth identities in auth.users.
-- This migration adds only public profile data and the module marketplace
-- catalog; package bytes are kept in a private Storage bucket.

create extension if not exists pgcrypto with schema extensions;

create type public.module_kind as enum ('system', 'user');
create type public.module_review_state as enum (
  'draft',
  'submitted',
  'published',
  'rejected',
  'suspended'
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create function public.create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name',
             new.raw_user_meta_data ->> 'full_name'),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.create_profile_for_auth_user();

create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute procedure public.touch_updated_at();

alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select, update on public.profiles to authenticated;

create policy "Users can read their own profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy "Users can update their own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create table public.modules (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+([.-][a-z0-9]+)*$'),
  kind public.module_kind not null,
  author_id uuid references auth.users (id) on delete cascade,
  publisher text,
  name text not null check (length(name) between 1 and 120),
  summary text not null default '' check (length(summary) <= 500),
  description text not null default '',
  category text not null,
  review_state public.module_review_state not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint module_owner_matches_kind check (
    (kind = 'system' and author_id is null and publisher = 'NerveGears') or
    (kind = 'user' and author_id is not null and publisher is null)
  )
);

create index modules_catalog_idx
  on public.modules (kind, category, name)
  where review_state = 'published';
create index modules_author_idx on public.modules (author_id, updated_at desc);

create function public.protect_module_authority()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  is_service_role boolean := coalesce(auth.role(), '') = 'service_role';
begin
  if new.kind = 'system' and not is_service_role then
    raise exception 'Only trusted publishing services may create or edit system modules';
  end if;

  if tg_op = 'UPDATE' then
    if (new.kind, new.author_id, new.publisher)
       is distinct from (old.kind, old.author_id, old.publisher) then
      raise exception 'Module ownership and publisher are immutable';
    end if;
    if new.review_state is distinct from old.review_state and not is_service_role then
      raise exception 'Only trusted review services may change module review state';
    end if;
  elsif new.kind = 'user' and new.review_state <> 'draft' then
    raise exception 'User modules must be created as drafts';
  end if;

  new.updated_at = now();
  return new;
end;
$$;

create trigger modules_protect_authority
  before insert or update on public.modules
  for each row execute procedure public.protect_module_authority();

create table public.module_releases (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references public.modules (id) on delete cascade,
  version text not null check (version ~ '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'),
  review_state public.module_review_state not null default 'draft',
  manifest jsonb not null check (jsonb_typeof(manifest) = 'object'),
  package_path text not null unique,
  package_sha256 text not null check (package_sha256 ~ '^[0-9a-f]{64}$'),
  signature text,
  min_engine_version text not null,
  created_at timestamptz not null default now(),
  published_at timestamptz,
  unique (module_id, version)
);

create index module_releases_published_idx
  on public.module_releases (module_id, published_at desc)
  where review_state = 'published';

create function public.protect_release_publication()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  is_service_role boolean := coalesce(auth.role(), '') = 'service_role';
begin
  if tg_op = 'UPDATE' and
     (new.module_id, new.version, new.manifest, new.package_path,
      new.package_sha256, new.signature)
       is distinct from
     (old.module_id, old.version, old.manifest, old.package_path,
      old.package_sha256, old.signature) then
    raise exception 'Published release metadata is immutable; upload a new version';
  end if;

  if new.review_state <> 'draft' and not is_service_role then
    raise exception 'Only trusted review services may publish a release';
  end if;
  if new.review_state = 'published' and new.published_at is null then
    new.published_at = now();
  end if;
  return new;
end;
$$;

create trigger module_releases_protect_publication
  before insert or update on public.module_releases
  for each row execute procedure public.protect_release_publication();

alter table public.modules enable row level security;
alter table public.module_releases enable row level security;
revoke all on public.modules, public.module_releases from anon, authenticated;
grant select on public.modules, public.module_releases to anon, authenticated;
grant insert, update, delete on public.modules, public.module_releases to authenticated;

create policy "Published modules are visible in the catalog"
  on public.modules for select to anon, authenticated
  using (review_state = 'published');
create policy "Authors can read their own modules"
  on public.modules for select to authenticated
  using (kind = 'user' and author_id = (select auth.uid()));
create policy "Users can create their own module drafts"
  on public.modules for insert to authenticated
  with check (
    kind = 'user' and author_id = (select auth.uid())
    and publisher is null and review_state = 'draft'
  );
create policy "Authors can edit their own modules"
  on public.modules for update to authenticated
  using (kind = 'user' and author_id = (select auth.uid()))
  with check (kind = 'user' and author_id = (select auth.uid()));
create policy "Authors can delete their own unpublished modules"
  on public.modules for delete to authenticated
  using (
    kind = 'user' and author_id = (select auth.uid())
    and review_state in ('draft', 'rejected')
  );

create policy "Published releases for published modules are visible"
  on public.module_releases for select to anon, authenticated
  using (
    review_state = 'published' and exists (
      select 1 from public.modules m
      where m.id = module_id and m.review_state = 'published'
    )
  );
create policy "Authors can read releases of their own modules"
  on public.module_releases for select to authenticated
  using (exists (
    select 1 from public.modules m
    where m.id = module_id and m.kind = 'user'
      and m.author_id = (select auth.uid())
  ));
create policy "Authors can add draft releases to their own modules"
  on public.module_releases for insert to authenticated
  with check (
    review_state = 'draft' and exists (
      select 1 from public.modules m
      where m.id = module_id and m.kind = 'user'
        and m.author_id = (select auth.uid())
    )
  );
create policy "Authors can delete draft releases of their own modules"
  on public.module_releases for delete to authenticated
  using (
    review_state = 'draft' and exists (
      select 1 from public.modules m
      where m.id = module_id and m.kind = 'user'
        and m.author_id = (select auth.uid())
    )
  );

-- Never expose package bytes through a public bucket. Trusted Edge Functions
-- validate/sign packages and mint short-lived download URLs after checking the
-- published catalog row and release. Keep the service-role key server-side.
insert into storage.buckets (id, name, public, file_size_limit)
values ('module-packages', 'module-packages', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = 52428800;
