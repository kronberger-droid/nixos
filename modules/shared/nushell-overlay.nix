# Overlay swapping nixpkgs' nushell for our helix-mode-wip fork build:
# current upstream (v0.114.0) + reedline's selection-first Helix edit mode
# (`edit_mode = "helix"`). See the `nushell-helix` input in flake.nix for the
# full rationale. Factored out here so every host gets the same build from a
# single source of truth — mkHost hosts and the homeserver (which is built
# outside mkHost) both import this. reedline is the lone git dep, pinned by the
# fork's Cargo.lock rev and fetched as a FOD; bump the hash when that rev moves.
inputs: final: prev: {
  nushell = prev.nushell.overrideAttrs (_old: {
    version = "0.114.0-helix-wip";
    src = inputs.nushell-helix;
    cargoDeps = final.rustPlatform.importCargoLock {
      lockFile = "${inputs.nushell-helix}/Cargo.lock";
      outputHashes = {
        "reedline-0.49.0" = "sha256-LI2136dJ4Bz6itsxYMPGaVBkC9HjqKEl1YM3af7H6KU=";
      };
    };
    doCheck = false;
  });
}
