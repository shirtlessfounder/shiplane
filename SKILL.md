---
name: shiplane
description: Helps an AI agent ship a product across a pluggable set of cloud services (GitHub, exe.dev, Supabase, Vercel, AWS, Cloudflare, Resend, OpenAI, Linear, and any service module the user drops in). Collects auth lazily per-service on first use and follows opinionated playbooks for each platform.
---

# shiplane

You are an AI agent working inside a `shiplane` skill. The user has installed
shiplane to give you a consistent way to operate across a pluggable set of
cloud services without them having to re-explain the stack each session.

## Default services shipped with shiplane

| service | purpose |
|---|---|
| **github** | source of truth, PRs, issues, CI |
| **exe** | long-running server VMs (systemd, SSE, websockets, cron) |
| **supabase** | managed Postgres + auth + realtime |
| **vercel** | Next.js frontend hosting + serverless routes |
| **aws** | S3, Lambda, RDS, CloudFront — reach for when you outgrow the native stack |
| **cloudflare** | Workers, R2, Pages, DNS |
| **resend** | transactional email |
| **openai** | direct OpenAI API (when not routing through a proxy) |
| **linear** | issue tracking |

Each service lives as a plugin under `scripts/services/<name>.sh`. The user
(or another agent) can drop new plugins in the same dir and they'll be
auto-discovered — no core changes required.

## Onboarding: lazy + agent-driven

Onboarding is NOT a separate step the user runs. You run it inline, only when
a service is actually needed. Flow:

1. User asks for an operation that needs a service (e.g. "deploy this to
   vercel").
2. You check that service's auth state first:

    ```bash
    bash ~/.claude/skills/shiplane/scripts/check-auth.sh <name>
    ```

3. If it exits non-zero, run the service's onboarding inline in the
   terminal so the user can complete browser logins / paste tokens:

    ```bash
    bash ~/.claude/skills/shiplane/scripts/services/<name>.sh
    ```

4. Once authed, proceed with the original operation.

Do NOT run a bulk `scripts/onboard.sh` for every service up front — that's
only for users who explicitly ask "onboard everything".

## Where credentials live

All metadata + secrets (for services without native CLIs) are stored at
`~/.config/shiplane/credentials.json` (mode `0600`). Native CLIs like `gh`,
`vercel`, `wrangler`, and `aws` also cache their own auth in their usual
locations (`~/.config/gh/`, `~/.local/share/com.vercel.cli/`, `~/.aws/`,
etc) — shiplane does not duplicate those.

Example shape (only populated for services the user has onboarded):

```json
{
  "github":    { "token": "ghp_...", "username": "shirtlessfounder" },
  "exe":       { "ssh_key_path": "~/.ssh/id_shiplane_exe", "default_host": "innies-api.exe.xyz" },
  "supabase":  { "access_token": "sbp_...", "default_project_ref": "rcx..." },
  "vercel":    { "token": "vercel_xxx...", "default_team": "shirtlessfounder" },
  "aws":       { "default_region": "us-east-1", "default_profile": "default" },
  "cloudflare":{ "api_token": "...", "default_account_id": "..." },
  "resend":    { "api_token": "re_..." },
  "openai":    { "api_token": "sk-..." },
  "linear":    { "api_token": "lin_api_..." }
}
```

Read a value with `jq`:

```bash
jq -r .aws.default_region ~/.config/shiplane/credentials.json
```

Never echo full tokens. When operating on a service, prefer letting its
native CLI pick up its own cached auth; only reach into `credentials.json`
when you need something a CLI can't provide (e.g. an API token for direct
curl calls).

## Playbooks (read on demand)

Each playbook is a deep-dive for one operation. Read only the ones you
currently need — don't preload all of them.

- [playbooks/github-pr-flow.md](playbooks/github-pr-flow.md)
- [playbooks/deploy-to-exe.md](playbooks/deploy-to-exe.md)
- [playbooks/supabase-migrations.md](playbooks/supabase-migrations.md)
- [playbooks/vercel-deploy.md](playbooks/vercel-deploy.md)
- [playbooks/aws.md](playbooks/aws.md)
- [playbooks/cloudflare.md](playbooks/cloudflare.md)
- [playbooks/resend.md](playbooks/resend.md)
- [playbooks/prod-from-scratch.md](playbooks/prod-from-scratch.md) — end-to-end walkthrough

## Templates (copy when scaffolding)

- [templates/prod.env.example](templates/prod.env.example)
- [templates/migration.sql](templates/migration.sql)
- [templates/systemd-service.template](templates/systemd-service.template)
- [templates/gitignore.template](templates/gitignore.template)

## Core conventions

1. **One PR = one squash-merged commit.** Branch off `main`, open PR, squash, delete branch.
2. **Migrations are numbered + idempotent.** `docs/migrations/NNN_name.sql` with guarded INSERTs; pair with `_no_extensions.sql` for superuser-less envs.
3. **Server-side env vars stay server-side.** Only `NEXT_PUBLIC_*` reaches the browser.
4. **exe.dev for long-running, Vercel for edges.** Anything needing SSE, websockets, LISTEN/NOTIFY, cron, or >10s requests → exe.dev. Stateless Next.js → Vercel.
5. **Supabase URLs need `?sslmode=no-verify`** for pg-node (self-signed chain from pg's perspective).
6. **Session pooler (`:5432`) for LISTEN/NOTIFY**; transaction pooler (`:6543`) for everything else.
7. **Reach for AWS / Cloudflare only when you outgrow the native stack.** Supabase + Vercel + exe.dev cover most needs until you need raw S3-style object storage, edge compute worldwide, or beefy EC2.

## Extending shiplane

Users can add new services without waiting for a shiplane release. Pattern:

```bash
# scripts/services/<new-service>.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/creds.sh"

shiplane_service_<new-service>_status() { ...; }
shiplane_service_<new-service>_onboard() { ...; }

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shiplane_service_<new-service>_onboard
fi
```

Drop the file in `scripts/services/`, make it executable (`chmod +x`), and it
auto-appears in `onboard.sh --list` / `check-auth.sh --list`.

## What shiplane is NOT

- Not a deployment tool — you still run the real CLIs (`gh`, `supabase`, `vercel`, `wrangler`, `aws`, `ssh`).
- Not a project generator — onboarding does NOT create new repos/projects/VMs. The user creates those.
- Not a secret manager — plain-JSON storage at `0600`. Single-user dev machines only; don't use on shared systems.
