#!/usr/bin/env bash
# Final checklist before running nixos-install.
# Verifies mounts, keys, config, and subvolumes are all in place.
#
# Usage: sudo ./04-pre-install-check.sh
set -euo pipefail

ERRORS=0
WARNS=0

pass() { echo "  [OK]   $1"; }
fail() { echo "  [FAIL] $1"; ERRORS=$((ERRORS+1)); }
warn() { echo "  [WARN] $1"; WARNS=$((WARNS+1)); }

echo "=== 1. Mount points ==="
for mp in / /boot /nix /nix/persist /home; do
  mountpoint -q "/mnt$mp" 2>/dev/null && pass "$mp mounted" || fail "$mp not mounted"
done
swapon --show | grep -q . && pass "swap active" || warn "swap not active"

echo ""
echo "=== 2. Btrfs subvolumes ==="
BTRFS_DEV=$(findmnt -n -o SOURCE /mnt | head -1 | sed 's/\[.*\]//')
if [ -n "$BTRFS_DEV" ]; then
  TMP_MNT=$(mktemp -d)
  mount -o subvol=/ "$BTRFS_DEV" "$TMP_MNT" 2>/dev/null && {
    for sv in @root @nix @persist @home; do
      [ -d "$TMP_MNT/$sv" ] && pass "subvolume $sv exists" || fail "subvolume $sv missing"
    done
    umount "$TMP_MNT"
  } || fail "could not mount btrfs top-level"
  rmdir "$TMP_MNT"
else
  fail "could not determine btrfs device"
fi

echo ""
echo "=== 3. Host SSH keys ==="
for loc in /mnt/nix/persist/etc/ssh /mnt/etc/ssh; do
  [ -f "$loc/ssh_host_ed25519_key" ] && pass "$loc/ssh_host_ed25519_key" || fail "$loc/ssh_host_ed25519_key missing"
done

echo ""
echo "=== 4. NixOS config ==="
FLAKE="/mnt/home/kronberger/.config/nixos"
[ -f "$FLAKE/flake.nix" ] && pass "flake.nix found" || fail "flake.nix not found at $FLAKE"
HW="$FLAKE/hosts/spectre/hardware-configuration.nix"
if [ -f "$HW" ]; then
  grep -q "btrfs" "$HW" && pass "hardware-config uses btrfs" || fail "hardware-config still uses ext4"
  grep -q "neededForBoot" "$HW" && pass "neededForBoot present" || fail "neededForBoot missing"
  grep -q "wipe-root" "$HW" && pass "wipe service present" || fail "wipe service missing"
  grep -q "<BTRFS-UUID>\|<ESP-UUID>\|<SWAP-UUID>" "$HW" && fail "hardware-config still has placeholders" || pass "no placeholders remaining"
else
  fail "hardware-configuration.nix not found"
fi

echo ""
echo "=== Summary ==="
echo "  $ERRORS error(s), $WARNS warning(s)"
if [ "$ERRORS" -gt 0 ]; then
  echo "  Fix errors before running: nixos-install --flake $FLAKE#spectre"
  exit 1
else
  echo "  Ready to install: sudo nixos-install --flake $FLAKE#spectre"
fi
