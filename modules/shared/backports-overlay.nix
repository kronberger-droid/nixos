# Fixes that nixpkgs master already has but the locked nixos-unstable does
# not. Each entry names the nixpkgs commit that makes it redundant, so the
# flake update that brings that commit in can drop the entry. Keep it to
# one-line overrides of upstream packages; anything bigger gets its own file
# like nushell-overlay.nix.
#
# An entry left in after its fix arrived is not harmless: the override still
# changes the derivation, so the package misses cache.nixos.org and builds
# here. Empty since the lock of 2026-11-21, which had caught up with all four
# it held (ironbar, rqbit, oo7-portal, matrix-tuwunel).
_final: _prev: {}
