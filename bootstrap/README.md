# bootstrap/

One-time scripts for onboarding a freshly-provisioned host that you can still
only reach with the provider's root password. They run **before** Ansible,
because they create the key-based user that Ansible then connects as. Once a
host is bootstrapped you never need them again for that host — they're kept
for reproducibility (rebuilds, additional hosts).

Both scripts are read from stdin and run on the remote as root. Supply the
password via `sshpass` (env var, never on the command line) or type it
interactively.

## `audit.sh` — read-only intrusion audit

Makes **no changes**. Collects login history, authorized_keys, accounts,
sudoers, cron, systemd units, listeners, and recently-modified files so you
can judge whether anyone used the host while it was reachable by password.
Review the output before changing anything; if it shows signs of compromise,
rebuild the host rather than harden it.

```sh
SSHPASS='THE_ROOT_PASSWORD' sshpass -e \
  ssh -o StrictHostKeyChecking=accept-new root@<SERVER_IP> 'bash -s' \
  < audit.sh | tee ~/civpvp-audit.md
```

Write the output **outside the repo** (e.g. your home dir, as above) — it
contains real host data (authorized_keys, accounts, history) and should never
be committed.

## `bootstrap-access.sh` — create a key-based sudo user

Creates the user (if absent), installs your SSH public key, and grants
passwordless sudo. Idempotent. Args: `<username> "<ssh public key>"`.

```sh
SSHPASS='THE_ROOT_PASSWORD' sshpass -e \
  ssh -o StrictHostKeyChecking=accept-new root@<SERVER_IP> \
  "bash -s -- <USERNAME> \"$(cat ~/.ssh/your_key.pub)\"" \
  < bootstrap-access.sh
```

Then verify key login + sudo **in a fresh session** before locking anything
down (keep the password session open as a fallback):

```sh
ssh -i ~/.ssh/your_key <USERNAME>@<SERVER_IP> 'sudo -n whoami'   # -> root
```

Only once that prints `root`, run the Ansible hardening (see repo README),
which disables password and root SSH login.
