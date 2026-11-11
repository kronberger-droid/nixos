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
  # nixpkgs #584231 (open, 2026-11-11): "oo7: 0.6.0 -> 0.7.1". Only the
  # portal is taken, and only for its fix: 0.6.0 wraps the fd libsecret
  # hands over as a UnixStream, so sending the master key down libsecret's
  # pipe fails ("Socket operation on non-socket") and every sandboxed
  # libsecret client (nixpak sets /.flatpak-info, and libsecret then insists
  # on the portal, whatever SECRET_BACKEND says) gets no secret. 0.7.1
  # writes to it as a plain file. The daemon and PAM stay on 0.6.0 until
  # the PR lands, since it also moves files oo7-nixos depends on.
  oo7-portal = prev.oo7-portal.overrideAttrs (finalAttrs: _old: {
    version = "0.7.1";
    src = prev.fetchFromGitHub {
      owner = "linux-credentials";
      repo = "oo7";
      tag = finalAttrs.version;
      hash = "sha256-mwmMCr3qmkMnm0L0W5XDJawM2GtM4SIXqtJSfaW/pgY=";
    };
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      inherit (finalAttrs) src;
      name = "oo7-${finalAttrs.version}-vendor";
      hash = "sha256-K0S3J6i3tf/yeu8dkrIvoKlImyFq+JipDrLz5bFy8q4=";
    };
  });
}
