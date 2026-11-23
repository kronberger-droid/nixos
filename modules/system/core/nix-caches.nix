{config, ...}: let
  inherit (import ../../shared/homeserver.nix) tailnet4;
in {
  nix.settings = {
    # Only caches that can hit. cache.nixos.org is the NixOS default and
    # needs no line. An input that follows our nixpkgs builds to hashes its
    # own CI never made, which is why nix-community is not here, and
    # nothing pushed to kronberger-droid.cachix.org: harmonia on the
    # homeserver serves our own builds. Every cache listed is asked for
    # every path the ones before it lack.
    substituters = [
      "https://claude-code.cachix.org"
      "https://helix.cachix.org"
    ];
    extra-substituters =
      if config.networking.hostName != "homeserver"
      then ["http://${tailnet4}:5001"]
      else [];
    connect-timeout = 5;
    fallback = true;
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "homeserver-cache:ahJGAGislENoHCxAZvgDJ7tE/k7pL2h5PvqMXoY0enY="
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
    ];
  };
}
