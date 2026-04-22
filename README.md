# shiplane

A Claude Code skill that teaches any AI agent how to ship a product on the
**GitHub + exe.dev + Supabase + Vercel** stack. Drop it into
`~/.claude/skills/shiplane/`, run the onboarding script once, and every future
agent session can spin up branches, run migrations, deploy servers, and push
Next.js frontends without you re-explaining the stack each time.

## What it does

- **Onboarding wizard** — `scripts/onboard.sh` walks you through logging into
  GitHub, exe.dev, Supabase, and Vercel. Credentials land at
  `~/.config/shiplane/credentials.json` (`0600`). No project creation — you
  bring your own existing accounts / projects.
- **Playbooks** — opinionated markdown guides the agent reads on demand for
  each common operation (PR flow, deploys, migrations, Vercel gotchas).
- **Templates** — starter files (systemd unit, migration shape, `.gitignore`,
  `prod.env`) the agent can copy when scaffolding new work.

## Install

```bash
git clone https://github.com/shirtlessfounder/shiplane ~/.claude/skills/shiplane
~/.claude/skills/shiplane/scripts/onboard.sh
```

Claude Code auto-discovers anything in `~/.claude/skills/` on start — no
config change needed. Next time you open Claude Code, the skill is available.

## Requirements

The onboarding script assumes these CLIs are installed. It checks each one and
tells you what's missing before collecting any auth:

| CLI | install |
|---|---|
| `gh` (GitHub) | `brew install gh` |
| `supabase` | `brew install supabase/tap/supabase` |
| `vercel` | `npm i -g vercel` |
| `ssh` | built-in on macOS/linux |
| `jq` | `brew install jq` |

You'll also need existing accounts on:

- [GitHub](https://github.com) — free
- [exe.dev](https://exe.dev) — VM hosting, free tier available
- [Supabase](https://supabase.com) — managed Postgres, free tier available
- [Vercel](https://vercel.com) — Next.js hosting, free tier available

## What gets stored locally

```json
~/.config/shiplane/credentials.json  (mode 0600)
{
  "github":   { "token", "username" },
  "exe":      { "ssh_key_path", "ssh_pubkey", "default_host" },
  "supabase": { "access_token", "default_project_ref" },
  "vercel":   { "token", "default_team" }
}
```

Plain JSON at `0600` — not encrypted at rest. Fine for a single-user dev
machine; don't use shiplane on shared systems. OS-keychain storage is a
roadmap item.

## Usage (for the user)

After install + onboarding, just ask your agent to ship something:

> "spin up a new node api on exe.dev with a `/healthz` endpoint and point a
> supabase migration at it"

The agent will read `SKILL.md`, follow the relevant playbook, copy templates
where needed, and run the real service CLIs. You stay in the loop — it'll ask
before destructive ops (push, merge, migrate, etc).

## Usage (for the agent)

See [`SKILL.md`](SKILL.md) — that's the entry point the Claude Code harness
loads. Everything agent-facing is there.

## Health check

Auth tokens expire. Run this any time an agent says "auth failed":

```bash
~/.claude/skills/shiplane/scripts/check-auth.sh
```

It validates each stored credential against the live service and prints
which are stale. Re-run `onboard.sh` to refresh anything expired.

## Non-goals

- Not a deployment tool (no `shiplane deploy` command — you still use real CLIs)
- Not a project generator (no `shiplane new` — onboarding explicitly avoids
  creating new resources on any platform)
- Not a secret manager (plain-JSON storage, not encrypted)

## License

MIT — see [LICENSE](LICENSE).
