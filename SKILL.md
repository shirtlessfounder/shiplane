---
name: shiplane
description: Helps an AI agent ship a product on GitHub + exe.dev + Supabase + Vercel. Reads locally-stored auth credentials and follows opinionated playbooks for the full lifecycle (branch → PR → migrate → deploy).
---

# shiplane

You are an AI agent working inside a `shiplane` skill. The user has installed shiplane
to give you a consistent way to operate across four services:

- **GitHub** — source of truth, PR flow, issue tracking
- **exe.dev** — long-running server processes (node/python/etc), systemd, auto-HTTPS
- **Supabase** — managed Postgres (with optional session pooler for LISTEN/NOTIFY)
- **Vercel** — Next.js frontend hosting + serverless routes

## Where credentials live

All auth lives at `~/.config/shiplane/credentials.json` (mode `0600`). Schema:

```json
{
  "github": {
    "token": "ghp_...",
    "username": "shirtlessfounder"
  },
  "exe": {
    "ssh_key_path": "~/.ssh/id_shiplane_exe",
    "ssh_pubkey": "ssh-ed25519 AAAA... shiplane",
    "default_host": "innies-api.exe.xyz"
  },
  "supabase": {
    "access_token": "sbp_...",
    "default_project_ref": "rcxokzsblffykipiljqv"
  },
  "vercel": {
    "token": "vercel_xxx...",
    "default_team": "shirtlessfounder"
  }
}
```

Read it with `jq` when you need a specific value:

```bash
GH_TOKEN=$(jq -r .github.token ~/.config/shiplane/credentials.json)
```

Never echo these tokens in full. Prefer letting the service CLIs (`gh`, `supabase`,
`vercel`, `ssh`) pick them up from their own auth state. Shiplane's onboarding script
runs each service's native `login` command, so 99% of the time you can just call
`gh pr create` / `supabase db push` / `vercel deploy` / `ssh <host> ...` without
explicitly passing a token.

If `~/.config/shiplane/credentials.json` doesn't exist, tell the user to run
`~/.claude/skills/shiplane/scripts/onboard.sh` first. Don't try to proceed without it.

## Playbooks (read on demand)

Each playbook is a deep-dive for one operation. Read the specific one you need —
don't preload them all.

- [playbooks/github-pr-flow.md](playbooks/github-pr-flow.md) — branch → PR → squash merge conventions
- [playbooks/deploy-to-exe.md](playbooks/deploy-to-exe.md) — ship a node process to an exe.dev VM with systemd + share auto-HTTPS
- [playbooks/supabase-migrations.md](playbooks/supabase-migrations.md) — safe migration patterns, pooler gotchas (:5432 vs :6543), `sslmode=no-verify`
- [playbooks/vercel-deploy.md](playbooks/vercel-deploy.md) — env vars, serverless timeout gotchas, NEXT_PUBLIC_ scope
- [playbooks/prod-from-scratch.md](playbooks/prod-from-scratch.md) — end-to-end from empty → deployed product

## Templates (copy when scaffolding)

- [templates/prod.env.example](templates/prod.env.example) — standard env shape for an exe.dev node service
- [templates/migration.sql](templates/migration.sql) — guarded-insert pattern for idempotent seeds
- [templates/systemd-service.template](templates/systemd-service.template) — systemd unit for `tsx src/server.ts`
- [templates/gitignore.template](templates/gitignore.template) — standard .gitignore for a node+supabase+vercel repo

## Core conventions to follow

These opinions are baked in — diverge only when the user asks.

1. **One PR = one squash-merged commit.** Branch off `main`, open PR, squash merge, delete branch. Never push directly to `main`.
2. **Migrations are numbered + idempotent.** `docs/migrations/NNN_description.sql` with guarded INSERTs (`insert ... where not exists`). Pair every file with a `_no_extensions.sql` variant if you use it in environments without superuser.
3. **Server-side env vars stay server-side.** Only `NEXT_PUBLIC_*` reaches the browser. Admin keys, DB URLs, seller tokens go in non-prefixed vars.
4. **exe.dev for long-running, Vercel for edges.** Anything needing SSE, websockets, LISTEN/NOTIFY, cron, or >10s request times goes to exe.dev. Stateless Next.js routes + static pages go to Vercel.
5. **Supabase URLs need `?sslmode=no-verify`** for pg-node — Supabase's TLS chain is self-signed from pg-node's perspective.
6. **Session pooler (:5432) for LISTEN/NOTIFY**; transaction pooler (:6543) for everything else. The transaction pooler drops the connection between queries so realtime won't work on it.

## Health check

If something's off, run `~/.claude/skills/shiplane/scripts/check-auth.sh` — it
validates each stored credential against the live service and prints which are
stale. Re-run onboarding if any have expired.

## What this skill is NOT

- Not a deployment tool — you still run the real service CLIs (`gh`, `supabase`, `vercel`, `ssh`). Shiplane just makes sure they're authed + gives you opinionated playbooks.
- Not a project generator — onboarding does not create new repos / projects / VMs. The user creates those manually (or asks you to, using the playbooks). This avoids shiplane accidentally spawning infrastructure users didn't expect.
- Not a secret manager — credentials are stored plain-JSON at `0600`. Good enough for single-user dev machines. Don't use shiplane on shared/multi-user systems.
