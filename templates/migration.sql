-- Template: guarded INSERT so this migration is safe to re-run.
-- Replace <TABLE>, <COLUMNS>, <VALUES>, and <UNIQUE_FILTER> with your specifics.
-- Pair this file with a `<NNN>_<name>_no_extensions.sql` sibling (same content
-- unless you're adding a CREATE EXTENSION — in which case strip it there).

begin;

-- ---- DDL (idempotent) ----
create table if not exists <TABLE> (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---- seed data (idempotent) ----
insert into <TABLE> (
  <COLUMNS>
)
select <VALUES>
where not exists (
  select 1 from <TABLE>
  where <UNIQUE_FILTER>
);

-- ---- grants (only if the role exists) ----
do $$
begin
  if exists (select 1 from pg_roles where rolname = '<some_app_role>') then
    grant all privileges on table <TABLE> to <some_app_role>;
  end if;
end $$;

commit;
