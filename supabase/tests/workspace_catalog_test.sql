-- Isolated PostgreSQL fixture: never run on the user's Supabase project.
create role anon;
create role authenticated;
create role service_role bypassrls;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
grant usage on schema auth to anon, authenticated;
create table public.profiles (id uuid primary key);
create type public.module_review_state as enum ('draft', 'submitted', 'published', 'rejected', 'suspended');
create function public.touch_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end;
$$;
insert into public.profiles values ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002');
\ir ../migrations/20261003122742_workspace_catalog.sql
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
insert into public.workspace_catalog (author_id, name, package) values
  (auth.uid(), 'Test workspace', '{"format":"qualia-workspace","version":1,"project":{"nodes":[],"links":[]}}');
do $$
begin
  if (select count(*) from public.workspace_catalog) <> 1 then raise exception 'Own submission invisible'; end if;
  begin
    insert into public.workspace_catalog (author_id, name, package) values
      ('00000000-0000-0000-0000-000000000002', 'Spoof', '{"format":"qualia-workspace","version":1,"project":{"nodes":[],"links":[]}}');
    raise exception 'Author spoof accepted';
  exception when insufficient_privilege then null; end;
  begin
    update public.workspace_catalog set review_state = 'published';
    raise exception 'Self-publication accepted';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.workspace_catalog (author_id, name, package) values (auth.uid(), 'Invalid', '{}');
    raise exception 'Invalid package accepted';
  exception when check_violation then null; end;
end;
$$;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ begin
  if exists (select 1 from public.workspace_catalog) then raise exception 'Other author sees private submission'; end if;
  delete from public.workspace_catalog;
end; $$;
set role anon;
do $$ begin
  if exists (select 1 from public.workspace_catalog) then raise exception 'Anon sees submission'; end if;
end; $$;
reset role;
update public.workspace_catalog set review_state = 'published';
set role anon;
do $$ begin
  if (select count(*) from public.workspace_catalog) <> 1 then raise exception 'Published graph invisible'; end if;
end; $$;
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
delete from public.workspace_catalog;
do $$ begin
  if (select count(*) from public.workspace_catalog) <> 1 then raise exception 'Other author deleted graph'; end if;
end; $$;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
delete from public.workspace_catalog;
do $$ begin
  if exists (select 1 from public.workspace_catalog) then raise exception 'Owner cannot delete'; end if;
end; $$;
reset role;
select 'Workspace catalog security checks passed' as result;
