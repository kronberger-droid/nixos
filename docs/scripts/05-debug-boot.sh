#!/usr/bin/env bash
# Post-boot debug script. Run on the installed system after reboot
# to check if impermanence and agenix are working.
#
# Usage: sudo ./05-debug-boot.sh
set -euo pipefail

echo "=== Impermanence ==="

# Check root is ephemeral (btrfs subvolume)
ROOT_SV=$(btrfs subvolume show / 2>/dev/null | head -1 || echo "unknown")
echo "  Root subvolume: $ROOT_SV"

# Check persist is mounted
mountpoint -q /nix/persist && echo "  [OK]   /nix/persist mounted" || echo "  [FAIL] /nix/persist not mounted"
mountpoint -q /home && echo "  [OK]   /home mounted" || echo "  [FAIL] /home not mounted"

echo ""
echo "=== Agenix secrets ==="
for secret in kronberger-password pia-credentials tuwien-vpn-password arrabbiata-config github-token; do
  if [ -f "/run/secrets/$secret" ]; then
    echo "  [OK]   /run/secrets/$secret ($(stat -c '%U:%G %a' "/run/secrets/$secret"))"
  else
    echo "  [FAIL] /run/secrets/$secret missing"
  fi
done

echo ""
echo "=== Host key identity ==="
if [ -f /etc/ssh/ssh_host_ed25519_key ]; then
  PUB=$(ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key 2>/dev/null || echo "unreadable")
  echo "  Active public key: $PUB"
  echo "  Check this matches the spectre key in secrets/secrets.nix"
else
  echo "  [FAIL] /etc/ssh/ssh_host_ed25519_key not found"
fi

echo ""
echo "=== Wipe service ==="
if systemctl cat initrd-wipe-root.service &>/dev/null; then
  echo "  [OK]   initrd wipe-root service exists"
else
  echo "  [WARN] initrd wipe-root service not found (check journalctl -b for initrd logs)"
fi

echo ""
echo "=== Wipe test ==="
MARKER="/test-impermanence-$(date +%s)"
touch "$MARKER" 2>/dev/null && echo "  Created $MARKER - reboot and check it's gone" || echo "  Could not create test marker on /"
