#!/usr/bin/env python3
"""Upload a single file to a password-authenticated SFTP host.

Fills the ecosystem gap: ansible.builtin.copy and friends bootstrap via a
remote shell (exec_command), which managed game-panel hosts disable. paramiko's
SFTPClient talks the SFTP subsystem directly, so this works against SFTP-only
endpoints.

Runs on the controller (connection: local) — uses paramiko from the playbook's
own Python (must be present there; e.g. ansible_python_interpreter:
ansible_playbook_python).
"""
from __future__ import annotations

import os
from ansible.module_utils.basic import AnsibleModule

DOCUMENTATION = r"""
---
module: sftp_put
short_description: Upload a file to a password-auth SFTP server.
description:
  - Uploads a single file to an SFTP server using password authentication via paramiko.
  - Runs locally on the controller, so connection:local is required.
  - Fills the gap where ansible.builtin.copy needs a remote shell (broken on SFTP-only hosts).
options:
  host:
    type: str
    required: true
    description: Remote SFTP hostname or IP.
  port:
    type: int
    default: 22
    description: Remote SFTP port.
  username:
    type: str
    required: true
    description: SFTP username.
  password:
    type: str
    required: true
    no_log: true
    description: SFTP password.
  src:
    type: path
    required: true
    description: Local source path.
  dest:
    type: str
    required: true
    description: Remote dest path (relative to the SFTP CWD/chroot).
  create_dirs:
    type: bool
    default: true
    description: mkdir -p the parent dir of dest if missing.
  force:
    type: bool
    default: false
    description: Always upload, skipping the size-equal idempotency check.
"""


def _mkdir_p(sftp, remote_dir: str) -> None:
    parts = remote_dir.strip("/").split("/")
    accum = "/" if remote_dir.startswith("/") else ""
    for part in parts:
        if not part:
            continue
        accum = (accum + "/" + part) if accum and not accum.endswith("/") else (accum + part)
        try:
            sftp.mkdir(accum)
        except OSError:
            pass  # already exists


def run_module() -> None:
    module = AnsibleModule(
        argument_spec=dict(
            host=dict(type="str", required=True),
            port=dict(type="int", default=22),
            username=dict(type="str", required=True),
            password=dict(type="str", required=True, no_log=True),
            src=dict(type="path", required=True),
            dest=dict(type="str", required=True),
            create_dirs=dict(type="bool", default=True),
            force=dict(type="bool", default=False),
        ),
        supports_check_mode=True,
    )

    try:
        import paramiko
    except ImportError:
        module.fail_json(msg="paramiko is not installed in the controller's Python. "
                             "Set ansible_python_interpreter to a Python that has it "
                             "(typically {{ ansible_playbook_python }}).")

    src = module.params["src"]
    dest = module.params["dest"]
    if not os.path.exists(src):
        module.fail_json(msg=f"src does not exist: {src}")
    local_size = os.path.getsize(src)

    ssh = paramiko.SSHClient()
    # TOFU: matches the looseness of the prior lftp `sftp:auto-confirm yes`.
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(
            module.params["host"],
            port=module.params["port"],
            username=module.params["username"],
            password=module.params["password"],
            look_for_keys=False,
            allow_agent=False,
        )
        sftp = ssh.open_sftp()
        try:
            changed = True
            if not module.params["force"]:
                try:
                    if sftp.stat(dest).st_size == local_size:
                        changed = False
                except FileNotFoundError:
                    pass

            if changed and not module.check_mode:
                if module.params["create_dirs"]:
                    parent = dest.rsplit("/", 1)[0] if "/" in dest else ""
                    if parent:
                        _mkdir_p(sftp, parent)
                sftp.put(src, dest)
        finally:
            sftp.close()
    except paramiko.AuthenticationException as e:
        module.fail_json(msg=f"SFTP authentication failed: {e}")
    except Exception as e:
        module.fail_json(msg=f"SFTP error: {type(e).__name__}: {e}")
    finally:
        ssh.close()

    module.exit_json(changed=changed, src=src, dest=dest)


if __name__ == "__main__":
    run_module()
