# Overlay swapping nixpkgs' nushell for our helix-mode fork build:
# current upstream (v0.114.2) + reedline's selection-first Helix edit mode
# (`edit_mode = "helix"`, reedline#1138). See the `nushell-helix` input in
# flake.nix for the full rationale. Factored out here so every host gets the
# same build from a single source of truth — mkHost hosts and the homeserver
# (which is built outside mkHost) both import this. reedline is the lone git
# dep, pinned by the fork's Cargo.lock rev and fetched as a FOD; bump the hash
# when that rev moves.
inputs: final: prev: {
  nushell = prev.nushell.overrideAttrs (old: {
    version = "0.114.2-helix";
    src = inputs.nushell-helix;
    cargoDeps = final.rustPlatform.importCargoLock {
      lockFile = "${inputs.nushell-helix}/Cargo.lock";
      outputHashes = {
        "reedline-0.49.0" = "sha256-BxNCweg8GrCQGxWt5+D52FWTuPbls15Z+30jphhkLU4=";
      };
    };
    # reedline#1138 and the fork's own glue both sit behind a cargo feature, so
    # without this the binary builds fine and just ignores `edit_mode = "helix"`.
    # It has to be `cargoBuildFeatures`, since that is what cargo-build-hook.sh
    # reads; `buildFeatures` is a buildRustPackage *argument* mapped to it at
    # eval time, thus setting it from overrideAttrs lands after the mapping and
    # does nothing at all.
    cargoBuildFeatures = (old.cargoBuildFeatures or []) ++ ["helix"];
    doCheck = false;
  });
}
