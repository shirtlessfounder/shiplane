# shiplane

A Claude Code skill that teaches any AI agent how to ship a product across a
pluggable set of cloud services. Drop it into `~/.claude/skills/shiplane/`
and every future agent session can branch, deploy, migrate, and auth without
re-explaining the stack.

## What's included

**Default service plugins** (each as a self-contained script under `scripts/services/`):

| service | purpose | auth method |
|---|---|---|
| **github** | source of truth, PRs, issues | `gh auth login` (browser OAuth) |
| **exe** | long-running VMs + auto-HTTPS | SSH key → dashboard |
| **supabase** | managed Postgres + realtime | personal access token |
| **vercel** | Next.js + edge functions | `vercel login` + API token |
| **aws** | S3, Lambda, RDS, etc | `aws configure` (IAM keys) |
| **cloudflare** | Workers, R2, Pages, DNS | `wrangler login` + API token |
| **resend** | transactional email | API token |
| **openai** | direct OpenAI API | API token |
| **linear** | issue tracking | personal API key |

**Playbooks** — opinionated guides the agent reads on demand:

- github PR flow · branch → PR → squash merge
- exe.dev deploys · systemd + `share port` auto-HTTPS
- supabase migrations · pooler gotchas, `sslmode=no-verify`, idempotent seeds
- vercel deploys · env var scope, serverless timeouts
- aws · when to reach for S3/Lambda/etc vs staying on the native stack
- cloudflare · Workers vs Vercel, R2 vs S3
- resend · domain verification gotcha
- prod-from-scratch · end-to-end walkthrough

**Templates** — starter files the agent can copy when scaffolding:

- `prod.env.example` — standard env shape for an exe.dev node service
- `migration.sql` — guarded-insert pattern for idempotent migrations
- `systemd-service.template` — systemd unit for `tsx src/server.ts`
- `gitignore.template` — standard repo gitignore

## Install

Tell Claude Code to add the skill:

> add shiplane skill https://github.com/shirtlessfounder/shiplane

(Or clone it yourself: `git clone https://github.com/shirtlessfounder/shiplane ~/.claude/skills/shiplane`)

Claude Code auto-discovers anything in `~/.claude/skills/` on startup.
Onboarding happens inline the first time an agent needs a service — you
don't need to run any bash wizard upfront.

## Manual onboarding (optional)

If you want to pre-onboard everything at once:

```bash
~/.claude/skills/shiplane/scripts/onboard.sh                 # all services
~/.claude/skills/shiplane/scripts/onboard.sh aws             # just one
~/.claude/skills/shiplane/scripts/onboard.sh --list          # show available
```

Check stored credentials against live services:

```bash
~/.claude/skills/shiplane/scripts/check-auth.sh              # all
~/.claude/skills/shiplane/scripts/check-auth.sh vercel aws   # subset
```

Native CLI auth persists across machine reboots, new Claude sessions, and
agent invocations — one-time ceremony per service per machine.

## Requirements

The services that have native CLIs need them installed. Onboarding will
check + tell you what's missing:

| CLI | install |
|---|---|
| `gh` (GitHub) | `brew install gh` |
| `supabase` | `brew install supabase/tap/supabase` |
| `vercel` | `npm i -g vercel` |
| `wrangler` (Cloudflare) | `npm i -g wrangler` |
| `aws` | `brew install awscli` |
| `jq` | `brew install jq` |
| `ssh` / `ssh-keygen` | built-in |

Resend / OpenAI / Linear are API-token-only — no CLI needed.

## Adding a new service

shiplane is pluggable. To add (say) Neon, Stripe, Datadog, or anything else:

1. Create `scripts/services/<name>.sh` following the existing plugin shape
   (see `scripts/services/openai.sh` for the simplest example)
2. Implement two functions:
   - `shiplane_service_<name>_status` — returns 0 if authed, non-zero if not
   - `shiplane_service_<name>_onboard` — runs the login flow
3. `chmod +x` the file

The new plugin auto-appears in `onboard.sh --list` / `check-auth.sh --list`
— no changes to core shiplane needed. Submit a PR if you think it'd benefit
others.

## Local credential storage

Non-CLI services store tokens at `~/.config/shiplane/credentials.json`
(mode `0600`). Native CLIs (gh, vercel, wrangler, aws, ssh) cache their own
auth in their usual locations — shiplane doesn't duplicate those.

Plain JSON at `0600` is fine for a single-user dev machine. Don't use
shiplane on shared/multi-user systems. OS keychain integration is a future
enhancement.

## Non-goals

- Not a deployment tool (no `shiplane deploy` command — agents use real CLIs)
- Not a project generator (no `shiplane new` — you create resources yourself)
- Not a secret manager (plain JSON at `0600`, not encrypted)

## License

MIT — see [LICENSE](LICENSE).
