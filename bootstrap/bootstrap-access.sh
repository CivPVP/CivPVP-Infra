#!/usr/bin/env bash
# Create a key-based sudo user. Run as root on the target.
# Args: $1 = username, $2 = SSH public key (single quoted string).
# Idempotent: safe to re-run.
set -euo pipefail

USERNAME="${1:?username required}"
PUBKEY="${2:?public key required}"

id "$USERNAME" >/dev/null 2>&1 || useradd -m -s /bin/bash "$USERNAME"

# Debian uses the 'sudo' group, RHEL uses 'wheel'.
if getent group sudo >/dev/null; then
  usermod -aG sudo "$USERNAME"
elif getent group wheel >/dev/null; then
  usermod -aG wheel "$USERNAME"
fi

HOME_DIR="$(getent passwd "$USERNAME" | cut -d: -f6)"
install -d -m 700 -o "$USERNAME" -g "$USERNAME" "$HOME_DIR/.ssh"
AUTH_KEYS="$HOME_DIR/.ssh/authorized_keys"
touch "$AUTH_KEYS"
# Add the key only if absent — never clobber other keys (keeps re-runs idempotent).
grep -qxF "$PUBKEY" "$AUTH_KEYS" || printf '%s\n' "$PUBKEY" >> "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
chown "$USERNAME:$USERNAME" "$AUTH_KEYS"

SUDO_FILE="/etc/sudoers.d/90-$USERNAME"
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$USERNAME" > "$SUDO_FILE"
chmod 440 "$SUDO_FILE"
visudo -cf "$SUDO_FILE"

echo "BOOTSTRAP OK: $USERNAME ready with key + passwordless sudo"
