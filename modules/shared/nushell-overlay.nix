# Overlay swapping nixpkgs' nushell (v0.114.2 release) for a build of upstream
# main, which carries the Helix edit mode (`edit_mode = "helix"`, reedline#1138
# + nushell#18830) ahead of the next release. Drop the overlay once nixpkgs
# ships a nushell that includes it. See the `nushell-src` input in flake.nix
# for the full rationale. Factored out here so every host gets the same build
# from a single source of truth — mkHost hosts and the homeserver (which is
# built outside mkHost) both import this. reedline is the lone git dep, pinned
# by main's Cargo.lock rev and fetched as a FOD; bump the hash when that rev
# moves.
inputs: final: prev: {
  nushell = prev.nushell.overrideAttrs (_: {
    # The "-helix" suffix is load-bearing: nushell.nix gates the helix
    # edit-mode config on `hasInfix "helix"` in the package version, so hosts
    # on the stock prebuilt package (mediaBox) fall back to vi.
    version = "0.114.2-helix";
    src = inputs.nushell-src;
    cargoDeps = final.rustPlatform.importCargoLock {
      lockFile = "${inputs.nushell-src}/Cargo.lock";
      outputHashes = {
        "reedline-0.49.0" = "sha256-N5SI5kYQyydQ0WO3Tn62lVP/969KHfXCjuqZHAffJmE=";
      };
    };
    # No feature flags needed: `helix` is in main's default feature set and
    # nixpkgs builds nushell with default features.
    doCheck = false;
  });
}
