# playbook: supabase migrations

Safe, idempotent migration patterns for Supabase postgres. Covers pooler
gotchas, the `sslmode=no-verify` quirk, and the guarded-insert style that
works across dev/staging/prod.

## Two pooler endpoints (know the difference)

Supabase gives every project two connection strings:

| port | pooler type | when to use |
|---|---|---|
| `:5432` | **session pooler** | anything that needs a persistent connection: `LISTEN`/`NOTIFY`, long transactions, logical replication |
| `:6543` | **transaction pooler** | 99% of normal queries — shorter-lived, auto-recycles between queries |

**Trap**: the transaction pooler drops your connection between queries, so
`LISTEN` doesn't work on it. If you're building SSE-backed realtime, you
**must** use `:5432`.

Store both in your `prod.env`:

```ini
DATABASE_URL=postgresql://postgres:<pw>@db.<ref>.supabase.co:6543/postgres?sslmode=no-verify
DATABASE_URL_SESSION=postgresql://postgres:<pw>@db.<ref>.supabase.co:5432/postgres?sslmode=no-verify
```

## The `sslmode=no-verify` trap

Supabase's TLS chain appears self-signed to node-pg's default validator.
Without `?sslmode=no-verify`, you'll get:

```
Error: self-signed certificate in certificate chain
```

Append `?sslmode=no-verify` to every Supabase connection string used by
pg-node. It still uses TLS — it just skips the self-signed chain check.

## Migration file convention

Numbered + paired:

```
docs/migrations/
├── 034_shared_documents.sql
├── 034_shared_documents_no_extensions.sql
├── 035_anthropic_model_claude_opus_4_7.sql
├── 035_anthropic_model_claude_opus_4_7_no_extensions.sql
```

The `_no_extensions` variant strips any `CREATE EXTENSION` / superuser-only
calls — useful for environments without superuser (some Supabase restrictions).
Often the two files are identical; keep them in sync so the pairing is obvious.

**Never reuse a migration number.** Always increment. If you collide locally,
rename yours to the next number before pushing.

## Idempotent seed pattern (guarded INSERT)

Migrations should be safe to re-run. For seed data:

```sql
insert into in_model_compatibility_rules (
  id, provider, model, is_enabled, effective_from
)
select
  '10570001-0000-4000-8000-000000000000'::uuid,
  'anthropic', 'claude-opus-4-7', true, now()
where not exists (
  select 1 from in_model_compatibility_rules
  where provider = 'anthropic' and model = 'claude-opus-4-7'
    and is_enabled = true
    and effective_from <= now()
    and (effective_to is null or effective_to > now())
);
```

For schema:

```sql
create table if not exists shared_documents (
  id text primary key,
  content text not null default '',
  ...
);

-- grants only if the role exists (lets the file run in fresh envs)
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'some_app_role') then
    grant all privileges on table shared_documents to some_app_role;
  end if;
end $$;
```

Wrap multi-statement migrations in `BEGIN; ... COMMIT;` so a partial failure
rolls back cleanly.

## Applying to prod

Via SSH (preferred — uses the prod secrets already on the VM):

```bash
ssh <host> 'sudo bash -c "source /etc/<app>/prod.env && \
  psql \"\$DATABASE_URL\" -f /tmp/034_xxx.sql"'
```

Or locally with the access token from shiplane creds:

```bash
SUPABASE_ACCESS_TOKEN="$(jq -r .supabase.access_token ~/.config/shiplane/credentials.json)" \
supabase db push
```

## Dumps + restores (cutover-style migrations)

When moving from one postgres to another:

```bash
# dump
pg_dump "$OLD_DATABASE_URL" \
  --no-owner --no-privileges --no-comments \
  --no-acl --clean --if-exists \
  > dump.sql

# Supabase-specific: strip superuser-only statements before restore
sed -i '' -E '/^ALTER TABLE .* DISABLE TRIGGER ALL;/d; /^ALTER TABLE .* ENABLE TRIGGER ALL;/d' dump.sql

# restore
psql "$NEW_DATABASE_URL" \
  -v ON_ERROR_STOP=1 \
  -c "SET session_replication_role = 'replica';" \
  -f dump.sql
```

## Never in migrations

- `DROP TABLE` / `DROP COLUMN` without first confirming no reads are pending.
  Prefer renaming out + cleaning up in a later migration.
- Mass backfills inside the same migration that adds the constraint.
  Separate the rollout: (1) add nullable column, (2) backfill in a job,
  (3) add the NOT NULL constraint in a later migration.
- `CREATE EXTENSION` without also shipping a `_no_extensions` variant.
- Non-idempotent operations. If your migration fails halfway and has to
  re-run, it must tolerate partial state.

## Useful queries

```sql
-- active models
select provider, model, is_enabled
from in_model_compatibility_rules
where is_enabled = true
order by provider, model;

-- recent archive rows for a buyer key
select id, request_id, started_at, status
from in_request_attempt_archives
where api_key_id = '<uuid>'
order by started_at desc
limit 20;

-- who owns what
select u.email, u.github_login, o.name as org, ak.id, ak.scope, ak.name
from in_api_keys ak
left join in_memberships m on m.id = ak.membership_id
left join in_orgs o on o.id = m.org_id
left join in_users u on u.id = m.user_id
order by ak.created_at desc;
```
