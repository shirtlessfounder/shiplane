# playbook: AWS

AWS is the "reach for this when the native stack isn't enough" layer. The
native shiplane stack (Vercel + exe.dev + Supabase) covers ~80% of SaaS
needs on its own. Only push to AWS when you genuinely need raw
infrastructure — otherwise the complexity cost eats the flexibility gain.

## When to actually reach for AWS

- **S3** — large/cheap object storage (images, video, PDFs). Vercel has
  Blob storage but pricing gets ugly past a few GB. Cloudflare R2 is often
  a better S3 alternative (no egress fees) — see the cloudflare playbook.
- **Lambda** — niche scheduled jobs or webhook handlers that need to live
  outside your Vercel/exe.dev footprint (e.g. a cross-account cron in a
  different AWS org).
- **RDS** — only if you've outgrown Supabase or need a region Supabase
  doesn't offer. Don't default here.
- **CloudFront** — you're almost certainly better off with Vercel's CDN or
  Cloudflare. Skip.
- **EC2** — exe.dev exists specifically to avoid managing EC2. Only reach
  here if you need bare metal or GPU.
- **SQS/SNS/EventBridge** — if your event flow has outgrown simple DB-backed
  queues. Early on, a postgres `jobs` table is usually enough.

## What you almost NEVER need AWS for (as a shiplane-stack product)

- Compute for a node API → use exe.dev
- Postgres → use Supabase
- Static + server-rendered frontend → use Vercel
- CDN → use Vercel (built-in) or Cloudflare (if you need more)
- Short-lived cron → Vercel Cron or exe.dev systemd timers
- Auth → Supabase Auth

## Access: IAM keys vs SSO

**Recommended: SSO (`aws sso login`)** for humans.

- Short-lived session credentials (~12h) — stolen keys expire quickly
- No long-lived secrets on your dev machine
- Centralized permission management

But shiplane's onboarding uses **`aws configure`** (long-lived IAM access
keys) because it's the lowest-friction option that works everywhere. That's
OK for dev-scale usage. For team/prod, switch to SSO:

```bash
aws configure sso --profile <profile-name>
aws sso login --profile <profile-name>
export AWS_PROFILE=<profile-name>
```

Rotate IAM keys quarterly if you stay on `aws configure`.

## Profile management

If you have multiple AWS accounts (personal + client + side project):

```bash
aws configure --profile client-x
aws configure --profile side-project
# day-to-day:
AWS_PROFILE=client-x aws s3 ls s3://client-bucket
```

Shiplane stores your `default_profile` in `credentials.json` — agents read
this when running AWS commands on your behalf.

## Region defaults

Pick **one region** per project and stick to it:

- **us-east-1** — cheapest, most services, highest blast radius during outages
- **us-west-2** — slightly more expensive, often more stable during
  us-east-1 outages
- **eu-west-1 / eu-central-1** — if you have EU users or GDPR constraints

Cross-region traffic costs money. If your Supabase project is in `us-east`,
put your AWS stuff in `us-east-1`.

## The two API patterns

```bash
# 1. aws CLI — it reads ~/.aws/credentials directly
aws s3 cp ./file.png s3://bucket/path/file.png

# 2. direct SDK (node/python/etc) — uses AWS_PROFILE env or default chain
AWS_PROFILE=client-x node my-script.js
```

shiplane's `credentials.json` doesn't store AWS secrets — the `aws` CLI
already does. Shiplane only remembers which profile + region you chose as
default so agents don't have to ask.

## Cost traps to watch for

- **NAT gateways** — ~$35/month each, often forgotten after VPC experiments
- **Unattached EBS volumes / EIPs** — billable even when not attached to a VM
- **S3 requests on hot paths** — GET requests add up fast; use CloudFront
  or signed URLs + client caching
- **CloudWatch logs retention** — default is forever, which adds up. Set
  retention to 7-30 days on all log groups
- **Data egress** — leaving AWS costs ~$0.09/GB. Cloudflare R2 has no
  egress fees → often cheaper for user downloads

## Common ops

```bash
# S3
aws s3 ls
aws s3 cp ./file s3://bucket/path
aws s3 sync ./local s3://bucket/remote
aws s3 presign s3://bucket/path --expires-in 3600

# Lambda (basic invoke)
aws lambda invoke --function-name <name> --payload '{"k":"v"}' out.json

# Identity / who am I
aws sts get-caller-identity

# List all my resources in a region (rough overview)
aws resourcegroupstaggingapi get-resources --region us-east-1 | jq '.ResourceTagMappingList[].ResourceARN'
```

## What NOT to do

- **Don't commit `~/.aws/credentials`** — it's local-only, never in git
- **Don't create IAM users for automated systems** — use IAM roles instead
- **Don't grant `AdministratorAccess` to service accounts** — least privilege
- **Don't forget to enable MFA on the root account** — AWS will bill you $∞
  if the root account gets compromised
