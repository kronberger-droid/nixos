#!/usr/bin/env bash
# Copy SSH host keys and user keys from a USB backup to the installed system.
# Run from the NixOS installer USB after mounting the root filesystem at /mnt.
#
# Usage: sudo ./copy-keys.sh /dev/sdX1
#   or:  sudo ./copy-keys.sh /path/to/already/mounted/spectre-keys
set -euo pipefail

SRC="${1:?Usage: $0 /dev/sdX1  OR  $0 /path/to/spectre-keys}"

# If argument is a block device, mount it
if [ -b "$SRC" ]; then
  mkdir -p /mnt/usb
  mount "$SRC" /mnt/usb
  KEYS="/mnt/usb/spectre-keys"
  UNMOUNT=true
else
  KEYS="$SRC"
  UNMOUNT=false
fi

[ -d "$KEYS/host" ] || { echo "ERROR: $KEYS/host/ not found"; exit 1; }

echo "=== Restoring host SSH keys ==="
mkdir -p /mnt/etc/ssh
cp "$KEYS"/host/ssh_host_* /mnt/etc/ssh/
chmod 600 /mnt/etc/ssh/ssh_host_*_key
chmod 644 /mnt/etc/ssh/ssh_host_*_key.pub
echo "  -> /mnt/etc/ssh/"

echo ""
echo "=== Restoring user SSH keys ==="
if [ -d "$KEYS/user-ssh" ]; then
  mkdir -p /mnt/home/kronberger/.ssh
  cp -r "$KEYS"/user-ssh/* /mnt/home/kronberger/.ssh/
  chmod 700 /mnt/home/kronberger/.ssh
  chmod 600 /mnt/home/kronberger/.ssh/id_* 2>/dev/null || true
  chmod 644 /mnt/home/kronberger/.ssh/*.pub 2>/dev/null || true
  echo "  -> /mnt/home/kronberger/.ssh/"
else
  echo "  SKIP: $KEYS/user-ssh/ not found"
fi

if [ "$UNMOUNT" = true ]; then
  echo ""
  umount /mnt/usb
  echo "  USB unmounted"
fi

echo ""
echo "=== Done. Verify with: ==="
echo "  ls -la /mnt/etc/ssh/"
echo "  ls -la /mnt/home/kronberger/.ssh/"
