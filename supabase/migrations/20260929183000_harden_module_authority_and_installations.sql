-- Harden the module workflow and record which published release a user has
-- installed.  Package bytes remain private; the desktop client only receives
-- release metadata and short-lived URLs from a trusted server function.

revoke execute on function public.create_profile_for_auth_user() from public;
revoke execute on function public.rls_auto_enable() from public;

create or replace function public.protect_module_authority()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  is_service_role boolean := coalesce(auth.role(), '') = 'service_role';
  is_owner boolean := new.author_id is not null
    and new.author_id = (select auth.uid());
begin
  if new.kind = 'system' and not is_service_role then
    raise exception 'Only trusted publishing services may create or edit system modules';
  end if;

  if tg_op = 'UPDATE' then
    if (new.kind, new.author_id, new.publisher)
       is distinct from (old.kind, old.author_id, old.publisher) then
      raise exception 'Module ownership and publisher are immutable';
    end if;

    if not is_service_role then
      if not is_owner then
        raise exception 'Only the module author may edit this module';
      end if;
      if old.review_state not in ('draft', 'rejected') then
        raise exception 'Only draft or rejected modules may be edited';
      end if;
      if new.review_state is distinct from old.review_state
         and not (
           old.review_state in ('draft', 'rejected')
           and new.review_state = 'submitted'
         ) then
        raise exception 'Authors may only submit draft modules for review';
      end if;
    end if;
  elsif new.kind = 'user' and new.review_state <> 'draft' then
    raise exception 'User modules must be created as drafts';
  end if;

  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.protect_release_publication()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  is_service_role boolean := coalesce(auth.role(), '') = 'service_role';
  module_author uuid;
begin
  select m.author_id into module_author
  from public.modules m
  where m.id = new.module_id and m.kind = 'user';

  if tg_op = 'UPDATE' and
     (new.module_id, new.version, new.manifest, new.package_path,
      new.package_sha256, new.signature, new.min_engine_version)
       is distinct from
     (old.module_id, old.version, old.manifest, old.package_path,
      old.package_sha256, old.signature, old.min_engine_version) then
    if is_service_role or old.review_state not in ('draft', 'rejected') then
      raise exception 'Published release metadata is immutable; upload a new version';
    end if;
  end if;

  if not is_service_role then
    if module_author is null or module_author <> (select auth.uid()) then
      raise exception 'Only the module author may edit this release';
    end if;
    if new.published_at is distinct from old.published_at then
      raise exception 'Only the trusted publisher may set published_at';
    end if;
    if old.review_state not in ('draft', 'rejected') then
      raise exception 'Only draft or rejected releases may be edited';
    end if;
    if new.review_state is distinct from old.review_state
       and not (
         old.review_state in ('draft', 'rejected')
         and new.review_state = 'submitted'
       ) then
      raise exception 'Authors may only submit releases for review';
    end if;
  end if;

  if tg_op = 'INSERT' and not is_service_role then
    if module_author is null or module_author <> (select auth.uid())
       or new.review_state <> 'draft' or new.published_at is not null then
      raise exception 'Authors may only create draft releases for their own modules';
    end if;
  end if;

  if new.review_state = 'published' and new.published_at is null then
    new.published_at = now();
  end if;
  return new;
end;
$$;

create table public.module_installations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  module_id uuid not null references public.modules (id) on delete cascade,
  release_id uuid not null references public.module_releases (id) on delete restrict,
  enabled boolean not null default true,
  granted_capabilities text[] not null default '{}',
  installed_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, module_id)
);

create index module_installations_user_idx
  on public.module_installations (user_id, updated_at desc);
create index module_installations_module_idx
  on public.module_installations (module_id);
create index module_installations_release_idx
  on public.module_installations (release_id);

create function public.protect_module_installation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  release_module_id uuid;
  release_state public.module_review_state;
  module_state public.module_review_state;
begin
  select r.module_id, r.review_state, m.review_state
    into release_module_id, release_state, module_state
  from public.module_releases r
  join public.modules m on m.id = r.module_id
  where r.id = new.release_id;

  if release_module_id is null or release_module_id <> new.module_id
     or release_state <> 'published' or module_state <> 'published' then
    raise exception 'Only published module releases may be installed';
  end if;
  if new.user_id <> (select auth.uid())
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Users may only manage their own module installations';
  end if;

  new.updated_at = now();
  return new;
end;
$$;

create trigger module_installations_protect
  before insert or update on public.module_installations
  for each row execute procedure public.protect_module_installation();

alter table public.module_installations enable row level security;
revoke all on public.module_installations from anon, authenticated;
grant select, insert, update, delete on public.module_installations to authenticated;

create policy "Users can read their own module installations"
  on public.module_installations for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can install published modules for themselves"
  on public.module_installations for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own module installations"
  on public.module_installations for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can uninstall their own modules"
  on public.module_installations for delete to authenticated
  using ((select auth.uid()) = user_id);

create trigger module_installations_touch_updated_at
  before update on public.module_installations
  for each row execute procedure public.touch_updated_at();

revoke execute on function public.protect_module_authority()
  from public, anon, authenticated;
revoke execute on function public.protect_release_publication()
  from public, anon, authenticated;
revoke execute on function public.protect_module_installation()
  from public, anon, authenticated;
revoke execute on function public.touch_updated_at()
  from public, anon, authenticated;
