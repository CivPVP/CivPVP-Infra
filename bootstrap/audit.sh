#!/usr/bin/env bash
# Read-only intrusion audit. Makes NO changes to the host.
# Run as root on the target: collects login history, persistence vectors,
# and live state to judge whether anyone connected while the box was
# reachable by password.
set -uo pipefail

section() { printf '\n\n===== %s =====\n' "$1"; }

section "HOST / OS"
uname -a || true
cat /etc/os-release 2>/dev/null || true
uptime || true
date -u

section "CURRENTLY LOGGED IN (w)"
w || true

section "SUCCESSFUL LOGINS (last -Fwi, most recent 50)"
last -Fwi 2>/dev/null | head -n 50 || true

section "FAILED LOGIN ATTEMPTS (lastb, most recent 50)"
lastb -Fwi 2>/dev/null | head -n 50 || true

section "AUTH LOG: accepted logins / sudo / user changes"
for log in /var/log/auth.log /var/log/secure; do
  [ -r "$log" ] && { echo "--- $log ---"; grep -E 'Accepted|sudo:|useradd|usermod|new user|new group' "$log" 2>/dev/null | tail -n 100; }
done
echo "--- journald (sshd) ---"
journalctl -u ssh -u sshd --no-pager 2>/dev/null | grep -E 'Accepted|Failed' | tail -n 100 || true

section "AUTHORIZED_KEYS (all users)"
for f in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
  [ -r "$f" ] && { echo "--- $f ---"; cat "$f"; }
done

section "ACCOUNTS: login-capable + any UID 0"
awk -F: '($3>=1000 && $3!=65534) || $3==0 {print $1" uid="$3" shell="$7}' /etc/passwd

section "SUDOERS"
cat /etc/sudoers 2>/dev/null | grep -vE '^\s*#|^\s*$' || true
for f in /etc/sudoers.d/*; do [ -r "$f" ] && { echo "--- $f ---"; cat "$f"; }; done

section "CRON (persistence)"
cat /etc/crontab 2>/dev/null || true
ls -la /etc/cron.d /etc/cron.daily /etc/cron.hourly 2>/dev/null || true
for f in /var/spool/cron/crontabs/* /var/spool/cron/*; do [ -r "$f" ] && { echo "--- $f ---"; cat "$f"; }; done

section "RECENTLY ADDED SYSTEMD UNITS (mtime < 30d)"
find /etc/systemd/system /lib/systemd/system \( -name '*.service' -o -name '*.timer' \) -mtime -30 2>/dev/null || true

section "LISTENING SOCKETS"
ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null || true

section "TOP PROCESSES BY CPU"
ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%cpu 2>/dev/null | head -n 15 || true

section "RECENTLY MODIFIED FILES in /etc /root /tmp /dev/shm (mtime < 30d)"
find /etc /root /tmp /dev/shm -type f -mtime -30 2>/dev/null | head -n 100 || true

section "ROOT BASH HISTORY"
cat /root/.bash_history 2>/dev/null | tail -n 100 || true

section "AUDIT COMPLETE"
