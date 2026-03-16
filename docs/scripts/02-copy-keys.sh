#!/usr/bin/env bash
# Copy SSH host keys and user keys into the persist subvolume.
# Also copies host keys to /mnt/etc/ssh/ for nixos-install (since
# impermanence bind mounts aren't active during install).
#
# Usage: sudo ./02-copy-keys.sh /mnt/usb/spectre-keys
set -euo pipefail

BACKUP="${1:?Usage: $0 /path/to/spectre-keys}"

[ -d "$BACKUP/host" ] || { echo "ERROR: $BACKUP/host/ not found"; exit 1; }

echo "=== Restoring host keys ==="

# Into persist (survives reboots via impermanence bind mount)
mkdir -p /mnt/nix/persist/etc/ssh
cp "$BACKUP"/host/ssh_host_* /mnt/nix/persist/etc/ssh/
chmod 600 /mnt/nix/persist/etc/ssh/ssh_host_*_key
chmod 644 /mnt/nix/persist/etc/ssh/ssh_host_*_key.pub
echo "  -> /mnt/nix/persist/etc/ssh/"

# Into /mnt/etc/ssh (needed during nixos-install, before bind mounts exist)
mkdir -p /mnt/etc/ssh
cp "$BACKUP"/host/ssh_host_* /mnt/etc/ssh/
chmod 600 /mnt/etc/ssh/ssh_host_*_key
chmod 644 /mnt/etc/ssh/ssh_host_*_key.pub
echo "  -> /mnt/etc/ssh/"

echo ""
echo "=== Restoring user SSH keys ==="
if [ -d "$BACKUP/user-ssh" ]; then
  mkdir -p /mnt/nix/persist/home/kronberger/.ssh
  cp -r "$BACKUP"/user-ssh/* /mnt/nix/persist/home/kronberger/.ssh/
  chmod 700 /mnt/nix/persist/home/kronberger/.ssh
  chmod 600 /mnt/nix/persist/home/kronberger/.ssh/id_* 2>/dev/null || true
  chmod 644 /mnt/nix/persist/home/kronberger/.ssh/*.pub 2>/dev/null || true
  echo "  -> /mnt/nix/persist/home/kronberger/.ssh/"
else
  echo "  SKIP: $BACKUP/user-ssh/ not found"
fi

echo ""
echo "=== Done. Run 03-verify-keys.sh to check everything matches ==="
