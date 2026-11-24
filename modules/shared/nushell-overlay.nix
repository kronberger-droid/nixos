# Overlay swapping nixpkgs' nushell for a build of upstream main. nixpkgs
# tracks releases, which lag main by a lot: the Helix edit mode was usable on
# main for months before it shipped. Bumping is `nix flake update nushell-src`
# and nothing else. Factored out here so every host gets the same build from a
# single source of truth: mkHost hosts and the homeserver (built outside
# mkHost) import this. Droid imports it cross-compiled; see
# droidNushellOverlay in flake.nix.
#
# Built with crane (./nushell-crane.nix), which compiles the third-party crates
# in a derivation of their own. A bump that leaves Cargo.lock alone reuses it
# and recompiles only nushell's workspace crates; one that touches the lock,
# which a week of upstream commits nearly always does, still rebuilds it.
#
# The expression already does what this overlay used to patch onto upstream's
# `buildRustPackage` one: no test run in the package, libgit2 and sqlite linked
# from the system as nixpkgs' cargo setup hook would force, and
# `passthru.shellPath`, which NixOS's users.users.<n>.shell needs to accept nu
# as a login shell. It also passes the input's rev as NU_COMMIT_HASH, which
# the old callPackage silently dropped, so `version` names the commit.
#
# Deliberately built against *our* nixpkgs and its rustc instead of consuming
# upstream's flake at scripts/nix: that flake pins its own nixpkgs and
# rust-overlay, and there is no nushell binary cache, so matching upstream's
# inputs byte for byte buys nothing and costs a second nixpkgs. nixpkgs' rustc
# clears nushell's rust-toolchain.toml with room to spare.
#
# `nu_plugin_gstat` comes out of the same expression, thus the same source and
# version as the shell that loads it: a plugin from nixpkgs is built for the
# release nixpkgs carries and the protocol check turns it away. Named on its
# own instead of going into `nushellPlugins` so that a package set without
# this overlay's nushell, droid's cross one, has no plugin to pick up by
# mistake.
inputs: final: _prev: let
  built = final.callPackage ./nushell-crane.nix {
    craneLib = inputs.crane.mkLib final;
    inherit (final.rustPlatform) bindgenHook;
    nushellSrc = inputs.nushell-src.outPath;
    commitHash = inputs.nushell-src.rev;
  };
in {
  inherit (built) nushell;
  nu_plugin_gstat = built.plugins.gstat;
}
