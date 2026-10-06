-- Declarative graph documents only; no executable artifacts or credentials.
-- Submission follows the existing catalog moderation boundary. Authors cannot
-- self-publish, edit an approved graph in place or impersonate another author.
create table public.workspace_catalog (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  description text not null default '' check (char_length(description) <= 4000),
  license text not null default 'CC-BY-4.0' check (license in ('CC0-1.0', 'CC-BY-4.0', 'CC-BY-SA-4.0')),
  package jsonb not null check (
    coalesce(octet_length(package::text) <= 2097152
    and package->>'format' = 'qualia-workspace'
    and package->>'version' = '1'
    and jsonb_typeof(package->'project') = 'object'
    and jsonb_typeof(package->'project'->'nodes') = 'array'
    and jsonb_array_length(package->'project'->'nodes') <= 500
    and jsonb_typeof(package->'project'->'links') = 'array'
    and jsonb_array_length(package->'project'->'links') <= 8000, false)
  ),
  review_state public.module_review_state not null default 'submitted',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index workspace_catalog_author_idx on public.workspace_catalog(author_id);
create index workspace_catalog_published_idx on public.workspace_catalog(created_at desc, id)
  where review_state = 'published';
create trigger workspace_catalog_touch_updated_at before update on public.workspace_catalog
  for each row execute function public.touch_updated_at();
alter table public.workspace_catalog enable row level security;
revoke all on public.workspace_catalog from anon, authenticated;
grant select on public.workspace_catalog to anon, authenticated;
grant insert (author_id, name, description, license, package) on public.workspace_catalog to authenticated;
grant delete on public.workspace_catalog to authenticated;
grant select, insert, update, delete on public.workspace_catalog to service_role;
create policy workspace_catalog_read_published on public.workspace_catalog
  for select to anon, authenticated using (review_state = 'published');
create policy workspace_catalog_read_own on public.workspace_catalog
  for select to authenticated using (author_id = (select auth.uid()));
create policy workspace_catalog_submit_own on public.workspace_catalog
  for insert to authenticated with check (
    author_id = (select auth.uid()) and review_state = 'submitted'
  );
create policy workspace_catalog_delete_own on public.workspace_catalog
  for delete to authenticated using (author_id = (select auth.uid()));
