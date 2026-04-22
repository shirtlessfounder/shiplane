# playbook: vercel deploys

Patterns for shipping the Next.js frontend on Vercel. Covers env var scope,
serverless function limits, and where to draw the line with exe.dev.

## What Vercel is good for

- Static pages + SSR/ISR Next.js routes
- Short-lived API routes (<10s)
- Edge middleware / redirects
- CDN + image optimization
- Preview deploys per PR (free, automatic)

## What Vercel is bad at (push to exe.dev instead)

- SSE (kills connection after ~25s)
- WebSockets (no first-class support)
- Long-running requests (>10s default, max 60s on paid plans)
- Background / cron jobs (use Vercel Cron separately or push to exe.dev)
- Big uploads (4.5MB body limit on serverless)
- `LISTEN`/`NOTIFY` on postgres (no persistent connection)

If in doubt, pattern: **UI + read endpoints → Vercel. Write-heavy +
long-lived connections → exe.dev.**

## Env vars: scope matters

Next.js gates env vars by prefix:

| prefix | where it's readable |
|---|---|
| `NEXT_PUBLIC_*` | browser + server |
| everything else | server only (never bundled into browser JS) |

**Rule of thumb**: secrets, DB URLs, admin API keys, upstream service tokens
go in non-prefixed vars. The client can still use them via server-side proxy
routes (`app/api/*/route.ts`) without ever exposing them to the user's browser.

Example — innies-work pattern:

```bash
# server-only: never leaves Vercel's edge functions
INNIES_ADMIN_API_KEY=abc123...
INNIES_API_BASE_URL=https://innies-api.exe.xyz
INNIES_MONITOR_API_KEY_IDS=uuid1,uuid2,uuid3

# public: OK to inline into browser JS
NEXT_PUBLIC_INNIES_API_BASE_URL=https://innies-api.exe.xyz
```

Then in `app/api/innies/live-sessions/route.ts`:

```ts
export async function GET(req: Request) {
  const adminKey = process.env.INNIES_ADMIN_API_KEY!;   // server-only
  const upstream = `${process.env.INNIES_API_BASE_URL}/v1/admin/me/live-sessions`;
  const res = await fetch(upstream, {
    headers: { 'x-api-key': adminKey }
  });
  return Response.json(await res.json());
}
```

Browser calls `/api/innies/live-sessions` (no auth needed), Vercel's edge
function injects the admin key server-side, the user never sees it.

## Setting env vars

Three ways:

1. **Vercel dashboard** — one at a time, tick which environments (prod /
   preview / development). Gets the job done but slow for bulk.
2. **`vercel env` CLI**:
   ```bash
   vercel env add INNIES_ADMIN_API_KEY production
   # paste value, pick environments
   vercel env pull .env.local          # sync down to local
   ```
3. **`.env.production` + `vercel env push`** — for bulk updates.

After changing any env var, Vercel **requires a redeploy** to pick it up on
existing prod:

```bash
vercel --prod
# or re-trigger from dashboard → Deployments → Redeploy
```

## Deploys

Three triggers:

1. **Git push to `main`** — auto-deploys to production (if the repo is linked).
2. **`vercel --prod`** — deploys the current working directory to production.
3. **`vercel` (no flag)** — deploys to a preview URL.

Preview URLs are free and ephemeral — great for showing work to the user
before promoting to prod.

## Linking a new repo to Vercel

Once per repo:

```bash
cd /path/to/repo
vercel link
# → asks you to pick scope (team) + project, creates .vercel/project.json
```

After linking, git pushes auto-deploy. The `.vercel/` dir is gitignored by
default — don't commit it.

## Using shiplane creds for scripted ops

The onboarding script stores a Vercel API token so you can script non-CLI
operations:

```bash
token="$(jq -r .vercel.token ~/.config/shiplane/credentials.json)"
curl -sf "https://api.vercel.com/v2/deployments?limit=5" \
  -H "Authorization: Bearer $token" | jq '.deployments[] | {url, state, created}'
```

## Common gotchas

- **"Function timeout after 10s"**: you're doing long work in a serverless
  route. Move it to exe.dev or split into a background job + status-polling endpoint.
- **Env var not picked up**: did you redeploy after adding it? `vercel --prod`
  or trigger a new deploy from the dashboard.
- **Browser can't reach env var**: it's missing the `NEXT_PUBLIC_` prefix, or
  you're trying to use it in a client component without the prefix.
- **Preview deploy works, prod doesn't**: env vars are scoped per environment.
  Check that the var is set for `Production` specifically in the dashboard.
- **`next build` fails on Vercel but passes locally**: Vercel uses a case-
  sensitive filesystem. `import Button from './Button'` won't find `button.tsx`
  on Vercel even though it works on macOS.

## What to do before pushing a frontend change

1. `npm run build` locally. If build fails, Vercel will fail too.
2. `npm test` if there's a test suite.
3. Open a PR — Vercel auto-deploys a preview URL per commit. Check the
   preview before merging.
4. Merge via squash — prod auto-deploys.
5. Hard-reload the prod URL to bypass browser favicon/asset caches.
