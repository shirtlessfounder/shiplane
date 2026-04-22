# playbook: Cloudflare

Cloudflare gives you three things worth using in the shiplane stack:

1. **DNS + proxy** — where you'd point your custom domain
2. **R2** — S3-compatible object storage with zero egress fees
3. **Workers** — edge compute (sometimes useful as a complement to Vercel/exe.dev)

**Cloudflare Pages** (their Vercel alternative) exists but Vercel is
usually the better pick for Next.js — stick with Vercel.

## Authentication

Two credentials to manage:

- **`wrangler login`** — OAuth flow for the Workers/R2 CLI. Opens browser.
- **API token** — for scripted API calls outside wrangler. Mint at
  [https://dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens).

Shiplane's onboarding does both. `wrangler` stores its own auth; the API
token lands in `credentials.json`.

## When to use R2 (vs S3)

| need | pick |
|---|---|
| Frequent user-facing downloads (profile pics, video, PDFs) | **R2** — no egress fees |
| Archival / cold storage with rare reads | **S3 Glacier** |
| Tight integration with AWS Lambda / Athena | **S3** |
| Everything else | **R2** by default — simpler pricing |

R2's killer feature: egress is free. Move 10TB/month out of S3 and you pay
~$900 in egress alone. Same traffic on R2 costs $0.

R2 is S3-compatible (same SDKs), so porting is usually just changing the
endpoint + credentials:

```ts
import { S3Client } from '@aws-sdk/client-s3';

const r2 = new S3Client({
  region: 'auto',
  endpoint: `https://${ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId: R2_KEY, secretAccessKey: R2_SECRET }
});
```

R2 API keys are separate from your main Cloudflare API token. Mint them
at `Dashboard → R2 → Manage R2 API Tokens`.

## DNS + proxy

If your product runs on a custom domain, Cloudflare is worth using as the
DNS provider (vs Vercel DNS or your registrar's DNS):

- **Proxy mode** (orange cloud) — Cloudflare terminates TLS + applies
  DDoS/WAF rules before forwarding to Vercel/exe.dev. Usually what you want.
- **DNS-only** (gray cloud) — Cloudflare just resolves the record; traffic
  goes direct to the origin.

Use proxy mode for front-facing production. Use DNS-only for records that
need to stay direct (e.g. mail servers, TLS-verifying endpoints).

## Workers — when to reach for them

Workers are small JS/TS functions that run on Cloudflare's edge network.
They shine when:

- You need low-latency responses worldwide (Vercel's edge is also global but
  Cloudflare has more POPs)
- You want `fetch()` with zero cold-start overhead
- You need a tiny auth-check layer sitting in front of a slower origin

They're bad for:

- Anything > 30s CPU time (hard limit)
- Anything needing Node-only APIs (they run on a V8 isolate, not Node.js)
- Heavy computation (memory limits are tight)

**Default**: put your Next.js on Vercel, put your node server on exe.dev,
and reach for a Worker only when you have a specific edge-latency case.

## Common ops

```bash
# wrangler is logged in?
wrangler whoami

# list your workers
wrangler deployments list

# tail a worker's logs
wrangler tail <worker-name>

# R2 via wrangler
wrangler r2 bucket list
wrangler r2 object put <bucket>/<key> --file=./file.png

# direct API — uses the token shiplane stored
token="$(jq -r .cloudflare.api_token ~/.config/shiplane/credentials.json)"
curl -sf "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer $token" | jq '.result[] | {id, name}'
```

## Gotchas

- **Proxied records can break WebSockets** on older Cloudflare plans.
  Enable WebSockets explicitly or use DNS-only mode for WS endpoints.
- **`fetch` from a Worker has no credential cache** — attach auth headers
  manually.
- **R2 `GetObject` egress is free but LIST is rate-limited** — paginate +
  cache listings.
- **Wrangler deploys go to "production" by default**. Use `--env staging`
  with a matching entry in `wrangler.toml` for staging environments.

## Picking between services (rough guide)

| need | pick |
|---|---|
| object storage, user-facing | **R2** |
| object storage, internal/AWS-tight | **S3** |
| edge functions, global, <30s | **Cloudflare Workers** |
| Next.js app, global | **Vercel** (still) |
| long-running node API | **exe.dev** |
| DNS + TLS termination for a custom domain | **Cloudflare proxy** |
