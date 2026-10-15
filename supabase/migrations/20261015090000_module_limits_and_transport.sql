-- Module protocol/package limits. The catalog keeps one immutable release row;
-- the manifest decides whether its package is portable or has native targets.
-- Package bytes remain private Storage objects and are not copied into Postgres.
insert into storage.buckets (id, name, public, file_size_limit)
values ('module-packages', 'module-packages', false, 2147483648)
on conflict (id) do update
set file_size_limit = 2147483648,
    public = false;
