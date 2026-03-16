#!/usr/bin/env bash
# Mount all btrfs subvolumes for installation or repair.
# Run from the NixOS installer USB.
#
# Usage: sudo ./01-mount-btrfs.sh /dev/nvme0n1
set -euo pipefail

DISK="${1:?Usage: $0 /dev/nvme0n1}"
ESP="${DISK}p1"
SWAP="${DISK}p2"
BTRFS="${DISK}p3"

echo "=== Disk layout ==="
lsblk -f "$DISK"
echo ""

# Verify partitions exist
for part in "$ESP" "$SWAP" "$BTRFS"; do
  [ -b "$part" ] || { echo "ERROR: $part not found"; exit 1; }
done

echo "=== Mounting subvolumes to /mnt ==="

mount -o subvol=@root,compress=zstd,noatime "$BTRFS" /mnt
echo "  / (root)        -> /mnt"

mkdir -p /mnt/{boot,nix,home}

mount "$ESP" /mnt/boot
echo "  /boot (ESP)     -> /mnt/boot"

mount -o subvol=@nix,compress=zstd,noatime "$BTRFS" /mnt/nix
echo "  /nix            -> /mnt/nix"

mkdir -p /mnt/nix/persist
mount -o subvol=@persist,compress=zstd,noatime "$BTRFS" /mnt/nix/persist
echo "  /nix/persist    -> /mnt/nix/persist"

mount -o subvol=@home,compress=zstd,noatime "$BTRFS" /mnt/home
echo "  /home           -> /mnt/home"

swapon "$SWAP"
echo "  swap            -> on"

echo ""
echo "=== Done. Verify with: findmnt -R /mnt ==="
findmnt -R /mnt
