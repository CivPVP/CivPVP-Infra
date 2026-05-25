# CivPVP-Infra

Infrastructure automation for self-hosted CivPVP services. This baseline
covers **host hardening** only — no application services are deployed yet.

## What it does

Takes a freshly-provisioned Ubuntu/Debian VPS and brings it to a safe baseline:

- A dedicated **key-only sudo user** (no password, no root SSH login).
- A **default-deny `ufw` firewall** (only SSH open).
- **fail2ban** guarding SSH.
- **Unattended security upgrades**.

## Layout

```
bootstrap/   One-time scripts to audit a new host and create the key-based
             sudo user (run before Ansible). See bootstrap/README.md.
ansible/     Repeatable, idempotent hardening run as the sudo user over SSH.
```

## Usage

1. **Bootstrap** the host (one-time) — see [`bootstrap/README.md`](bootstrap/README.md):
   audit the host, then create your key-based sudo user.

2. **Configure your inventory** (kept out of git):

   ```sh
   cd ansible
   cp inventory.example.ini inventory.ini
   # edit inventory.ini with your host IP, sudo user, and key path
   ```

3. **Harden**:

   ```sh
   ansible-galaxy collection install -r requirements.yml
   ansible-playbook harden.yml
   ```

   The playbook is idempotent — re-run it any time; a clean run reports
   `changed=0`. The SSH lockdown drop-in is named `00-` so it wins sshd's
   first-match ordering over a cloud image's `50-cloud-init.conf`.

## Roadmap

- **Application services.** Deploy via Docker Compose stacks delivered by
  Ansible, with secrets managed through `ansible-vault`.
