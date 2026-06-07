# CivPVP-Infra

Deployment automation for [CivDiscord](https://github.com/grepsedawk/CivDiscord),
the Discord ↔ Minecraft bridge, onto the CivPVP servers hosted on
mint-servers.

It runs entirely from the operator's machine — there is no dedicated host.
The play downloads the released plugin jars, renders configs, pushes
everything to each game server over SFTP, and restarts the servers through
the Pterodactyl client API.

## Layout

```
ansible/
  civdiscord.yml              deploy playbook (hosts: localhost)
  restart.yml                 restart-only playbook (no redeploy)
  ansible.cfg                 vault auto-decrypt via .vault_pass
  group_vars/civdiscord/
    vars.yml                  deploy targets (citadel, proxy) + uuids
    vault.yml                 secrets (gitignored): SFTP, Pterodactyl key,
                              Discord token, NameLayer DB creds
  roles/civdiscord/           SFTP push + Pterodactyl restart
  certs/civdiscord-secret.key bridge HMAC secret (gitignored)
bin/
  mc-logs                     tail any backend's latest.log via the panel API
```

## Usage

```sh
cd ansible
ansible-playbook civdiscord.yml
```

`.vault_pass` decrypts `group_vars/civdiscord/vault.yml` automatically. The
play uploads the jars + configs and does **not** restart anything — the new jar
loads on the next restart. Pass `-e civdiscord_version=vX.Y.Z` to pin a
different release.

Restart the servers (separate from deploy):

```sh
ansible-playbook restart.yml
```

Tail a backend's log:

```sh
bin/mc-logs citadel        # or: proxy
```
