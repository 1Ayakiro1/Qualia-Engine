-- Authors can transition their own draft/rejected releases to submitted.
create policy "Authors can edit releases of their own modules"
  on public.module_releases for update to authenticated
  using (exists (
    select 1 from public.modules m
    where m.id = module_id and m.kind = 'user'
      and m.author_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.modules m
    where m.id = module_id and m.kind = 'user'
      and m.author_id = (select auth.uid())
  ));

create or replace function public.protect_module_installation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  release_module_id uuid;
  release_state public.module_review_state;
  module_state public.module_review_state;
  allowed_capabilities text[];
begin
  select r.module_id, r.review_state, m.review_state,
    coalesce(array(
      select jsonb_array_elements_text(
        case
          when jsonb_typeof(r.manifest -> 'capabilities') = 'array'
            then r.manifest -> 'capabilities'
          else '[]'::jsonb
        end
      )
    ), '{}'::text[])
    into release_module_id, release_state, module_state, allowed_capabilities
  from public.module_releases r
  join public.modules m on m.id = r.module_id
  where r.id = new.release_id;

  if release_module_id is null or release_module_id <> new.module_id
     or release_state <> 'published' or module_state <> 'published' then
    raise exception 'Only published module releases may be installed';
  end if;
  if not (new.granted_capabilities <@ allowed_capabilities) then
    raise exception 'Installation requests a capability not declared by the release';
  end if;
  if new.user_id <> (select auth.uid())
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Users may only manage their own module installations';
  end if;

  new.updated_at = now();
  return new;
end;
$$;

revoke execute on function public.create_profile_for_auth_user()
  from public, anon, authenticated;
revoke execute on function public.rls_auto_enable()
  from public, anon, authenticated;
