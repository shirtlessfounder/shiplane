# playbook: Resend

Resend is a transactional email API. Simple to integrate, but there's one
gotcha that bites everyone on their first send.

## The domain verification trap

You cannot send email from `@yourdomain.com` until Resend's DNS checks pass.
The flow:

1. Add your domain at [https://resend.com/domains](https://resend.com/domains).
2. Resend gives you ~4 DNS records (SPF, DKIM, DMARC, Return-Path) to add
   at your DNS provider.
3. You add them (Cloudflare, Namecheap, Vercel, etc).
4. Resend auto-verifies (usually within a few minutes).
5. Only then can you send from that domain.

**Until verification passes**, sends will fail with a `422` error even if
your API token works fine. If your onboarding shows `✓ resend API token
saved` but `⚠ no verified sending domains yet` — add + verify a domain
before you try to actually send.

## Choosing a sending domain

- **Don't send from your bare root** (`yourdomain.com`). Reserve the root
  for human email + marketing. Use a subdomain for transactional:
  `mail.yourdomain.com`, `notifications.yourdomain.com`, `hello.yourdomain.com`.
- Subdomain isolation limits deliverability damage if a transactional flow
  ever gets flagged as spam — your root domain's reputation stays clean.

## API tokens — two types

1. **Full access** — create/delete domains, send email, manage API keys.
   Use this for local dev + admin scripts.
2. **Sending access** — only send email. Use this in production / CI.
   Rotate more freely; blast radius is limited to "can send email as you".

Onboarding takes whichever one you paste; it doesn't distinguish. Mint a
separate sending-access token for prod when you're ready to deploy.

## Sending (minimal example)

```ts
import { Resend } from 'resend';
const resend = new Resend(process.env.RESEND_API_KEY);

await resend.emails.send({
  from: 'hello@mail.yourdomain.com',
  to: 'dylan@example.com',
  subject: 'hi',
  html: '<p>hello from resend</p>'
});
```

## Gotchas

- **Sandbox mode** (Resend's default until domain is verified) only lets
  you send *to* your own account email. Not to real users. Easy to miss
  during testing.
- **React Email** is Resend's sibling tool — nice template system. Use it
  if you're writing anything more complex than a plain paragraph.
- **Webhooks for bounce/complaint handling** are a separate flow. Set them
  up via Resend → Webhooks → point at an endpoint on your exe.dev server.
  Don't put webhooks on Vercel if you expect high volume — Vercel's
  serverless timeouts will eat bursts.
- **Batch sends**: 100 emails/request max. For larger lists, chunk + queue.
- **Attachments** are base64-encoded in the request body. >4MB attachments
  are better handled by uploading to S3/R2 and linking, not attaching.

## Common ops

```bash
token="$(jq -r .resend.api_token ~/.config/shiplane/credentials.json)"

# list verified domains
curl -sf https://api.resend.com/domains \
  -H "Authorization: Bearer $token" | jq

# send a test email
curl -sf https://api.resend.com/emails \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json" \
  -d '{
    "from": "hello@mail.yourdomain.com",
    "to": "you@gmail.com",
    "subject": "resend test",
    "html": "<p>it works</p>"
  }' | jq
```
