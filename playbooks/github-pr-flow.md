# playbook: github PR flow

Opinionated branch → PR → squash-merge flow. Read this before running any
`git push` or `gh pr` commands on the user's behalf.

## The flow

```
main           o───────o───────o───────o
                \               /
feature-branch   o──o──o──o──o─/
                  (1)(2)(3)(4) squash merge → 1 commit on main
```

1. Always branch off the latest `main`:
   ```bash
   git fetch origin main
   git checkout -b <type>/<kebab-description> origin/main
   ```
2. Make commits freely on the branch — they'll be squashed anyway.
3. When ready, open a PR:
   ```bash
   gh pr create --title "..." --body "$(cat <<'EOF'
   ## Summary
   - what changed
   - why

   ## Test plan
   - [x] what you ran / observed
   EOF
   )"
   ```
4. Squash merge:
   ```bash
   gh pr merge <number> --squash
   ```
5. Branch is auto-deleted on merge if you pass `--delete-branch`. If you
   forgot, the remote branch still gets cleaned up when the user hits the
   auto-delete toggle in repo settings.

## Branch naming conventions

Use a type prefix to signal intent. Pick one:

| prefix | when |
|---|---|
| `feat/...` | new user-facing capability |
| `fix/...` | bugfix |
| `chore/...` | tooling, configs, deps, renames, assets, non-code |
| `refactor/...` | internal restructuring, no behavior change |
| `test/...` | tests only |
| `docs/...` | README / playbook / comment changes only |

Example: `feat/cli-default-opus-4-7`, `fix/update-stale-landing-tests`.

## Commit messages (on the squash commit)

Format:

```
<type>(<scope>): <one-line summary, imperative, lowercase>

<body — what + why. explain the WHY in detail; the diff shows the WHAT>

Co-Authored-By: <your-model-name> <noreply@anthropic.com>
```

- Keep the first line under 72 chars.
- Body lines under 80 chars.
- Reference related PRs by number (`#199`, `#200`) when relevant.

## Things NOT to do

- **Never force-push to `main`.** Always through PRs.
- **Never amend a pushed commit.** Create a new commit instead.
- **Never use `--no-verify` to bypass hooks** unless the user explicitly asks.
- **Never skip tests before opening a PR.** Run the project's test suite first.

## Special cases

- **Squash merge conflicts with `main`**: `git fetch origin main && git rebase
  origin/main`, resolve, force-push to the feature branch (never `main`).
- **Pre-existing test failures**: note them in the PR body ("pre-existing
  failures, unrelated to this change"). Confirm they were failing before your
  changes by stashing + re-running tests on `main`.
- **Emergency hotfix**: same flow, faster. `fix/` prefix, tight scope, no
  bundled cleanup. Open the PR, merge immediately after the user signs off.

## Using `gh` with shiplane creds

The onboarding script runs `gh auth login`, so `gh` already has its own token
stored. You don't need to pass one from shiplane's credentials file unless
you're shelling out to the GitHub REST API directly:

```bash
# gh CLI — uses its own stored auth
gh pr create --title "..."

# direct API — pull token from shiplane creds
token="$(jq -r .github.token ~/.config/shiplane/credentials.json)"
curl -H "Authorization: Bearer $token" https://api.github.com/repos/...
```
