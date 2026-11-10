# Fixes that nixpkgs master already has but the locked nixos-unstable does
# not. Each entry names the nixpkgs commit that makes it redundant, so the
# flake update that brings that commit in can drop the entry. Keep it to
# one-line overrides of upstream packages; anything bigger gets its own file
# like nushell-overlay.nix.
_final: prev: {
  # nixpkgs b377d9a (#585944, 2026-11-10): "ironbar: fix build with system
  # libgit2". Same cause as the nushell overlay, the cargo setup hook's
  # LIBGIT2_NO_VENDOR=1 since nixpkgs 44cddf9.
  ironbar = prev.ironbar.overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [prev.libgit2];
  });
  # nixpkgs #585197 (open, 2026-11-09): "rqbit: use system aws-lc". The hook
  # also exports AWS_LC_SYS_USE_SYSTEM=1, and aws-lc-sys then refuses to
  # build its bundled copy. Only the build input is taken from that PR; it
  # bumps rqbit to 9.1.0 as well.
  rqbit = prev.rqbit.overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [prev.aws-lc];
  });
}
