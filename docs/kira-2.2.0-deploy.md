# Deploy: kira 2.2.0

Self-hosted Kira fork with the prefix → slash command migration complete.

## Prerequisites

- [ ] Image pushed to `ghcr.io/civpvp/kira:2.2.0` AND `:latest`. The
      `kira` repo's `.github/workflows/release.yml` does this automatically
      when a `v*` tag is pushed (uses the workflow's `GITHUB_TOKEN` — no
      PAT). To force a rebuild, re-run the workflow via `gh workflow run
      release.yml --repo CivPVP/kira -f tag=2.2.0` or push a new tag.
- [ ] GHCR package visibility set to public (one-time, via GitHub UI:
      Org → Packages → kira → Change package visibility).
- [ ] In the CivPVP Discord (guild `1441231139422339286`): create or
      designate a role to gate `/admin`. Suggested name: `kira-admin`.
      Assign yourself to it. Note the role ID via Developer Mode →
      right-click → Copy ID.

## Deploy

1. Confirm the image exists at the tag in `ansible/group_vars/vps/vars.yml`
   (`kira_image: "ghcr.io/civpvp/kira:2.2.0"`).
2. Run the playbook against the VPS:
   ```
   ansible-playbook -i ansible/inventory.ini ansible/kira.yml
   ```
3. Expect: `kira` container pulled at the new tag, container restarted.
   The playbook is idempotent — other tasks should report `ok=N`.
4. Verify in container logs:
   ```
   ansible vps -i ansible/inventory.ini -a "docker logs --tail 80 kira"
   ```
   Look for JDA init lines and the new slash commands registering against
   the guild (you'll see ~10 top-level slash commands enumerated).

## Post-deploy: grant /admin

By design, `/admin` is hidden from everyone (including you, the server
owner) until you explicitly grant it to a Discord role:

1. In the CivPVP Discord: **Server Settings → Integrations → Kira →
   /admin → Manage → Roles & Members → Add → `kira-admin` → Save.**
2. Confirm: type `/admin` in any channel where you have the role. Should
   auto-complete. (`/admin` only registers on the root guild
   `1441231139422339286` per the design's layer-1 gate.)

## Smoke test (in the CivPVP Discord, non-destructive first)

- [ ] `/info`, `/quote`, `/whoami` — sanity.
- [ ] `/help` — lists the full command tree.
- [ ] `/api token list` — succeeds (may be empty).
- [ ] `/relay list` — shows existing relays.
- [ ] `/admin server list` — lists guilds Kira is in.
- [ ] Send a message in an existing relay channel — confirm in-game
      receipt (this is the highest-stakes regression check).
- [ ] `/admin console command:list` — real test if there's a live MC
      server attached. Skip if not.
- [ ] **DO NOT** `/admin stop` unless you intend to test the container
      auto-restart.

## Rollback

If anything breaks: flip `kira_image` back to `ghcr.io/civmc/kira:2.1.1`
in `ansible/group_vars/vps/vars.yml` and re-run `ansible-playbook
ansible/kira.yml`. The old image stays in upstream's GHCR; pull will
succeed.

## Known limitations shipping in 2.2.0

- `/api token new` is half-ephemeral: the "Contacting ingame server..."
  ack is ephemeral, but the async token delivery via
  `supplier.reportBack()` posts publicly to the channel (matches
  upstream behavior). Fix tracked as a FIXME in
  `src/main/kotlin/net/civmc/kira/command/api/ApiCommand.kt`; requires
  a new `InteractionHookInputSupplier` shim that wraps the interaction
  hook.
- No automated test suite. Per the spec non-goal; manual verification
  covers it.

## Upstream PR

After ~1 week of stable production: open a courtesy PR to CivMC/Kira
with the same diff. If accepted, retire this fork.
