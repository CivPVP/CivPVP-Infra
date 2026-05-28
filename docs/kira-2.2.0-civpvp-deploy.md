# Deploy: kira 2.2.0-civpvp

Self-hosted Kira fork with the prefix → slash command migration complete.
Design spec: `../../kira/docs/superpowers/specs/2026-05-28-kira-slash-commands-design.md` (in the sibling kira repo).

## Prerequisites

- [ ] Image pushed to `ghcr.io/civpvp/kira:2.2.0-civpvp` AND `:latest`.
      Run from `~/Code/CivPVP/kira`:
      ```
      echo $GITHUB_PAT | docker login ghcr.io -u <username> --password-stdin
      docker push ghcr.io/civpvp/kira:2.2.0-civpvp
      docker push ghcr.io/civpvp/kira:latest
      ```
      First push may need package visibility set to public via the GitHub UI
      (Settings → Packages → kira → Change package visibility).
- [ ] PAT for GHCR scope: `write:packages` (for push) and `read:packages` (for
      pull on the VPS — verify VPS docker is authed or package is public).
- [ ] In the CivPVP Discord (guild `1441231139422339286`): create or designate
      a role to gate `/admin`. Suggested name: `kira-admin`. Assign yourself
      to it. Note the role ID via Developer Mode → right-click → Copy ID.

## Deploy

1. Confirm this branch is merged (or run from this branch locally).
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
   Look for JDA init lines and the new slash commands registering against the
   guild (you'll see ~10 top-level slash commands enumerated).

## Post-deploy: grant /admin

By design, `/admin` is hidden from everyone (including you, the server owner)
until you explicitly grant it to a Discord role:

1. In the CivPVP Discord: **Server Settings → Integrations → Kira → /admin
   → Manage → Roles & Members → Add → `kira-admin` → Save.**
2. Confirm: type `/admin` in any channel where you have the role. Should
   auto-complete. (`/admin` only registers on the root guild
   `1441231139422339286` per the design's layer-1 gate.)

## Smoke test (in the CivPVP Discord, non-destructive first)

- [ ] `/info`, `/quote`, `/whoami` — sanity.
- [ ] `/help` — lists the full command tree.
- [ ] `/api token list` — succeeds (may be empty).
- [ ] `/relay list` — shows existing relays.
- [ ] `/admin server list` — lists guilds Kira is in.
- [ ] Send a message in an existing relay channel — confirm in-game receipt
      (this is the highest-stakes regression check).
- [ ] `/admin console command:list` — real test if there's a live MC server
      attached. Skip if not.
- [ ] **DO NOT** `/admin stop` unless you intend to test the container
      auto-restart.

## Rollback

If anything breaks: flip `kira_image` back to `ghcr.io/civmc/kira:2.1.1` in
`ansible/group_vars/vps/vars.yml` and re-run `ansible-playbook ansible/kira.yml`.
The old image stays in upstream's GHCR; pull will succeed.

## Known limitations shipping in 2.2.0-civpvp

- `/api token new` is half-ephemeral: the "Contacting ingame server..." ack is
  ephemeral, but the async token delivery via `supplier.reportBack()` posts
  publicly to the channel (matches upstream behavior). Fix tracked as a FIXME
  in `src/main/kotlin/net/civmc/kira/command/api/ApiCommand.kt`; requires a
  new `InteractionHookInputSupplier` shim that wraps the interaction hook.
- No automated test suite. Per the spec non-goal; manual verification covers it.

## Upstream PR

After ~1 week of stable production: open a courtesy PR to CivMC/Kira with
the same diff. If accepted, retire this fork.
