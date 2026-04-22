# playbook: from empty → deployed product

End-to-end walkthrough for a brand-new product on the shiplane stack.
Assumes the user has run `onboard.sh` successfully (all four services
authed). This playbook intentionally does NOT automate project creation —
the user creates each resource in their dashboards, then tells the agent
"point shiplane at it."

## Shape of a shiplane-style repo

```
<product>/
├── api/                          # node server for exe.dev
│   ├── src/
│   │   └── server.ts
│   ├── package.json
│   └── tsconfig.json
├── web/                          # Next.js for Vercel
│   ├── src/app/
│   ├── package.json
│   └── next.config.mjs
├── docs/
│   ├── migrations/               # numbered + idempotent SQL
│   │   ├── 001_init.sql
│   │   └── 001_init_no_extensions.sql
│   └── ops/
│       └── INFRASTRUCTURE.md     # canonical "where things live" doc
├── README.md
└── .gitignore
```

Two workspaces (`api/` + `web/`) in one repo — avoids cross-repo PRs for
changes that touch both sides.

## Step 1: bootstrap the repo

User creates the repo in GitHub (agents don't auto-create repos — that's a
deliberate shiplane non-goal). Once it exists:

```bash
git clone git@github.com:<user>/<product>.git
cd <product>
cp ~/.claude/skills/shiplane/templates/gitignore.template .gitignore

# api workspace
mkdir -p api/src
cd api
npm init -y
npm install --save-dev tsx typescript @types/node
npm install express
# write api/src/server.ts, api/tsconfig.json, etc

# web workspace
cd ..
npx create-next-app@latest web --typescript --tailwind --app --no-src-dir
```

First commit:

```bash
git add .
git commit -m "chore: scaffold api + web workspaces"
git push origin main
```

## Step 2: supabase setup

User creates a Supabase project via dashboard and shares:

- project ref (e.g. `rcxokzsblffykipiljqv`)
- db password (for the connection string)

Build both pooler URLs and store them locally for development:

```bash
# api/.env.local — gitignored, never committed
cat > api/.env.local <<EOF
DATABASE_URL=postgresql://postgres:<pw>@db.<ref>.supabase.co:6543/postgres?sslmode=no-verify
DATABASE_URL_SESSION=postgresql://postgres:<pw>@db.<ref>.supabase.co:5432/postgres?sslmode=no-verify
EOF
chmod 600 api/.env.local
```

Write the first migration:

```bash
mkdir -p docs/migrations
cp ~/.claude/skills/shiplane/templates/migration.sql docs/migrations/001_init.sql
# edit it to create your tables
cp docs/migrations/001_init.sql docs/migrations/001_init_no_extensions.sql
```

Apply to the Supabase project:

```bash
SUPABASE_ACCESS_TOKEN="$(jq -r .supabase.access_token ~/.config/shiplane/credentials.json)" \
psql "$(grep ^DATABASE_URL= api/.env.local | cut -d= -f2-)" \
  -f docs/migrations/001_init.sql
```

## Step 3: exe.dev VM for the api

User creates a VM via exe.dev dashboard. Write the hostname somewhere the
agent can read (e.g. update `.exe.default_host` in shiplane creds).

First-time VM setup (see `deploy-to-exe.md` for details):

```bash
ssh <host>
# install node, clone repo, install deps, write /etc/<app>/prod.env,
# write /etc/systemd/system/<app>.service, enable + start, run `share port`.
```

Subsequent deploys = `git pull + systemctl restart`.

## Step 4: Vercel for the web

User creates a Vercel project, links repo (via dashboard or `vercel link`),
and adds env vars from their local `.env.local`:

```bash
cd web
vercel link                 # links this dir to the Vercel project
vercel env add DATABASE_URL production          # paste value
vercel env add NEXT_PUBLIC_API_BASE_URL production
# ...
vercel --prod               # deploy
```

Custom domain (if using one) → Vercel dashboard → Domains → add.

## Step 5: put it all together

You now have:
- GitHub repo: source of truth
- Supabase: data layer with migrations under version control
- exe.dev: long-running api serving `https://<host>.exe.xyz`
- Vercel: frontend at `https://<product>.vercel.app` (or custom domain)
  calling the api

Next steps — work via the `github-pr-flow.md` playbook. Every change goes
branch → PR → squash merge → (if api changed) SSH deploy → (if web changed)
Vercel auto-deploys from main.

## What to write down

Before you lose the context: create `docs/ops/INFRASTRUCTURE.md` in the repo
with:

- Supabase project ref + dashboard URL
- exe.dev hostname + SSH user
- Vercel project name + team slug
- Custom domain (if any) + DNS provider
- Where each env var lives (local vs prod vs Vercel)
- Who has access to each dashboard

Future-you (and future agents) will thank you.

## What NOT to do

- **Don't put secrets in the repo.** Use each platform's env-var UI.
- **Don't skip the `_no_extensions.sql` variant.** Future environments will
  need it.
- **Don't let `main` and prod drift.** If prod is pinned to an older SHA,
  note it in `INFRASTRUCTURE.md` + schedule the catch-up deploy.
- **Don't commit `.vercel/project.json`** — it's gitignored by default; keep
  it that way.
