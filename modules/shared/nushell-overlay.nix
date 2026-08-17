# Overlay swapping nixpkgs' nushell for a build of upstream main. nixpkgs
# tracks releases, which lag main by a lot: the Helix edit mode was usable on
# main for months before it shipped. Bumping is `nix flake update nushell-src`
# and nothing else. Factored out here so every host gets the same build from a
# single source of truth — mkHost hosts, the homeserver and droid (both built
# outside mkHost) all import this.
#
# The build is upstream's own package expression rather than a hand-rolled
# overrideAttrs on nixpkgs' derivation. It reads the version out of Cargo.toml,
# assembles src with lib.fileset, and sets `cargoLock.allowBuiltinFetchGit`,
# which is what keeps the git-pinned reedline dep from needing a hash here —
# builtins.fetchGit takes the rev straight from main's Cargo.lock. That was the
# one recurring maintenance cost of the old overlay.
#
# Deliberately callPackage'd against *our* nixpkgs instead of consuming
# upstream's flake at scripts/nix: that flake pins its own nixpkgs and
# rust-overlay, and unlike rio (see the rio-upstream input) there is no nushell
# binary cache, so matching upstream's inputs byte for byte buys nothing and
# costs a second nixpkgs. nixpkgs' rustc clears nushell's rust-toolchain.toml
# with room to spare — upstream targets ~2 releases behind stable on purpose —
# so their `rustPlatform'` isn't needed either.
inputs: _final: prev: {
  nushell = (prev.callPackage "${inputs.nushell-src}/scripts/nix" {})
    .overrideAttrs (old: {
    # Carried over from the previous overlay. nushell's suite is long and
    # some of it forks ptys, which is a poor fit for the sandbox; upstream CI
    # gates main already. Note this has to go through overrideAttrs — the
    # package expression ends in `...` and ignores unknown callPackage args,
    # so passing doCheck there would be silently dropped.
    doCheck = false;
    # `shellPath` is a nixpkgs convention with no meaning to nushell itself,
    # so upstream's expression has no reason to set it — but NixOS's
    # users.users.<n>.shell rejects any package without it ("is not a shell
    # package"), which is fatal here since nu is the login shell everywhere.
    # It goes in passthru, not meta: lib.types.shellPackage checks
    # `hasAttr "shellPath"` on the derivation itself, and passthru is what
    # lands attrs there.
    passthru = (old.passthru or {}) // {shellPath = "/bin/nu";};
  });
}
