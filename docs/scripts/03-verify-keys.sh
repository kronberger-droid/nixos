#!/usr/bin/env bash
# Verify that the host key on disk matches what secrets.nix expects.
# This is the #1 reason agenix fails to decrypt after install.
#
# Usage: sudo ./03-verify-keys.sh
set -euo pipefail

EXPECTED_PUB="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMo/agXzq/uXYxPRHuxy20rD/T09I/zQzLFjFmA5b5Ic"

echo "=== Checking host key locations ==="

check_key() {
  local path="$1"
  local label="$2"

  if [ ! -f "$path" ]; then
    echo "  MISSING: $label ($path)"
    return 1
  fi

  local actual
  actual=$(ssh-keygen -y -f "$path" 2>/dev/null) || {
    echo "  BROKEN:  $label - cannot read private key at $path"
    return 1
  }

  # Compare just the key type and key data (ignore trailing comment)
  local actual_short="${actual% *}"
  local expected_short="${EXPECTED_PUB% *}"

  if [ "$actual_short" = "$expected_short" ]; then
    echo "  OK:      $label"
    return 0
  else
    echo "  MISMATCH: $label"
    echo "    expected: $EXPECTED_PUB"
    echo "    got:      $actual"
    return 1
  fi
}

ERRORS=0

# Check persist location (used after boot via bind mount)
check_key "/mnt/nix/persist/etc/ssh/ssh_host_ed25519_key" "persist" || ERRORS=$((ERRORS+1))

# Check direct location (used during nixos-install)
check_key "/mnt/etc/ssh/ssh_host_ed25519_key" "install" || ERRORS=$((ERRORS+1))

echo ""
echo "=== Checking file permissions ==="
for dir in /mnt/nix/persist/etc/ssh /mnt/etc/ssh; do
  if [ -d "$dir" ]; then
    echo "  $dir:"
    ls -la "$dir"/ssh_host_ed25519_key* 2>/dev/null || echo "    (no ed25519 key)"
  fi
done

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "=== All keys match secrets.nix. Agenix should be able to decrypt. ==="
else
  echo "=== $ERRORS problem(s) found. Fix before running nixos-install. ==="
  echo ""
  echo "If keys are lost, generate new ones and re-encrypt secrets:"
  echo "  ssh-keygen -t ed25519 -f /mnt/nix/persist/etc/ssh/ssh_host_ed25519_key -N ''"
  echo "  cat /mnt/nix/persist/etc/ssh/ssh_host_ed25519_key.pub"
  echo "  # Update the spectre key in secrets/secrets.nix, then: agenix -r"
  exit 1
fi
