# playbook: deploy a node server to exe.dev

exe.dev gives you a long-running VM with auto-HTTPS via `share`. Use it for
anything that outgrows Vercel's 10s timeout: SSE, websockets, postgres
LISTEN/NOTIFY, cron jobs, large uploads.

## When to reach for exe.dev (vs Vercel)

- **SSE (Server-Sent Events)** — Vercel serverless kills long-lived
  connections. exe.dev keeps them open indefinitely.
- **WebSocket server** — same story.
- **`LISTEN`/`NOTIFY` on postgres** — needs a persistent connection + session
  pooler; Vercel functions can't hold one.
- **Request > 10s** — Vercel's default function timeout.
- **Cron / background jobs** — exe.dev keeps them running; Vercel needs
  scheduled functions (separate product).
- **Large request bodies** — Vercel has a 4.5MB body cap by default.

## Assumptions

- You have an exe.dev account.
- SSH key is set up (shiplane onboarding did this + wrote the path to
  `.exe.ssh_key_path`).
- The VM host is either stored as `.exe.default_host` in creds or passed by
  the user.
- You've already SSH'd into the host once (so it's in `known_hosts`).

## First-time VM setup

The user creates the VM in their exe.dev dashboard. Once it exists:

```bash
ssh <host>  # e.g. ssh innies-api.exe.xyz

# install node (once per VM) — use nvm or nodesource
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# clone the repo (read the playbooks/prod-from-scratch.md for the
# full repo-layout convention)
sudo git clone https://github.com/<user>/<repo> /opt/<repo>
cd /opt/<repo>/api
sudo npm install
```

## Writing the systemd service

Copy `templates/systemd-service.template` and fill in the gaps:

```ini
[Unit]
Description=<app-name>
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/<repo>/api
EnvironmentFile=/etc/<app>/prod.env
ExecStart=/opt/<repo>/api/node_modules/.bin/tsx src/server.ts
Restart=always
RestartSec=3
User=ubuntu

[Install]
WantedBy=multi-user.target
```

Save at `/etc/systemd/system/<app>.service`, then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable <app>
sudo systemctl start <app>
sudo systemctl status <app>
```

## Environment variables

Store prod env vars at `/etc/<app>/prod.env` (not in the repo, not in git):

```bash
sudo mkdir -p /etc/<app>
sudo nano /etc/<app>/prod.env
sudo chmod 600 /etc/<app>/prod.env
```

Use `templates/prod.env.example` as the shape. Reference it from systemd via
`EnvironmentFile=/etc/<app>/prod.env`.

## Auto-HTTPS via `share`

exe.dev's `share` command exposes a port on the VM at a public HTTPS URL with
auto-issued TLS:

```bash
# on the VM
share port 3000
# → returns https://<host>.exe.xyz

share set-public <host>
# makes it accessible without exe.dev login auth

share set-private <host>
# re-gates behind exe.dev's auth wall
```

Stick this behind a systemd unit too so it survives reboots, or use
`nohup share port 3000 &` for quick tests.

## Deploy (subsequent iterations)

After the initial setup, deploys are just a `git pull` + `systemctl restart`:

```bash
ssh <host> "cd /opt/<repo> && sudo git fetch origin main && \
  sudo git checkout main && sudo git pull origin main && \
  sudo systemctl restart <app> && sleep 3 && \
  sudo systemctl status <app> --no-pager | head -12"
```

Watch the first few seconds of logs for crashes:

```bash
ssh <host> "sudo journalctl -u <app> --since '10 seconds ago' --no-pager | tail -20"
```

## Debugging

- Logs: `sudo journalctl -u <app> -f` (follow)
- Env check: `sudo systemctl show <app> -p Environment`
- Restart: `sudo systemctl restart <app>`
- Full restart incl deps: `sudo systemctl stop <app> && sudo systemctl start <app>`

## Common gotchas

- **`tsx` not found**: make sure `npm install` ran in the `WorkingDirectory`
  and the `ExecStart` path is absolute to `node_modules/.bin/tsx`.
- **Crash on boot but works manually**: usually an env var missing from
  `prod.env` that was set in your shell during manual testing.
- **`share` URL returns exe.dev login page**: run `share set-public <host>`.
- **Port in use after crash**: `sudo lsof -i :3000` then `kill` the pid.

## What to do before pushing code that needs exe.dev changes

1. Test locally first.
2. Commit + push + PR + merge via the `github-pr-flow` playbook.
3. SSH and deploy (the `git pull + systemctl restart` snippet above).
4. Tail logs for the first 10-30 seconds. If anything looks wrong, roll back
   with `git checkout <previous-sha> && systemctl restart <app>`.
