# Vendored & patched copy of nix-on-droid's modules/environment/path.nix
# (rev 55b6449b, the flake.lock pin), swapped in via disabledModules below.
#
# Why: upstream's installPackages activation runs `nix-env --install`, which
# instantiates and BUILDS a fresh user-environment derivation on-device at
# activation time. proot on this phone denies the builder's pseudoterminal
# ("error: getting pseudoterminal attributes: Permission denied", see
# nix-on-droid#423), so that build can never succeed — and because the
# activation script is `set -e`, the switch dies there, before the
# home-manager step in activationAfter ever runs. Net effect: bare bash
# login with none of the HM dotfiles (no bash->nu handoff, no config).
#
# Fix: environment.path is already a buildEnv of environment.packages and is
# realised during the *build* phase of `nix-on-droid switch` (it is part of
# the generation closure — activation.nix symlinks it into the generation),
# and that phase works fine under proot. `nix-env --set` points the profile
# generation directly at that pre-built path without building anything, so
# the pty is never allocated. The profile tree it produces is equivalent to
# what `nix-env --install` built (the buildEnv contents), minus the
# manifest.nix — which nix-on-droid never consults, since every switch
# re-sets the whole profile anyway.
#
# This replacement is needed (rather than a plain option override) because
# build.activation is types.attrs: last definition wins and upstream's
# modules are evaluated after this config, so a user-level redefinition of
# build.activation.installPackages silently loses. Everything except the
# nix-env branch is upstream-verbatim; drop this file and its import if
# upstream fixes #423.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.environment;
in {
  disabledModules = ["${inputs.nix-on-droid}/modules/environment/path.nix"];

  ###### interface (upstream-verbatim)

  options = {
    environment = {
      packages = mkOption {
        type = types.listOf types.package;
        default = [];
        description = "List of packages to be installed as user packages.";
      };

      path = mkOption {
        type = types.package;
        readOnly = true;
        internal = true;
        description = "Derivation for installing user packages.";
      };

      extraOutputsToInstall = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["doc" "info" "devdoc"];
        description = "List of additional package outputs to be installed as user packages.";
      };
    };
  };

  ###### implementation

  config = {
    build.activation.installPackages = ''
      if [[ -e "${config.user.home}/.nix-profile/manifest.json" ]]; then
        # New-style profile: `nix profile` materialises the env client-side
        # (no builder process, no pty), so upstream's logic is kept as-is.
        # manual removal and installation as two non-atomical steps is required
        # because of https://github.com/NixOS/nix/issues/6349

        nix_previous="$(command -v nix)"

        nix profile list \
          | grep 'nix-on-droid-path$' \
          | cut -d ' ' -f 4 \
          | xargs -t $DRY_RUN_CMD nix profile remove $VERBOSE_ARG

        $DRY_RUN_CMD $nix_previous profile install ${cfg.path}

        unset nix_previous
      else
        # Legacy profile: --set instead of upstream's --install, so nothing
        # is built on-device (see header comment for the proot pty story).
        $DRY_RUN_CMD nix-env --set ${cfg.path}
      fi
    '';

    environment = {
      packages = [
        (pkgs.callPackage "${inputs.nix-on-droid}/nix-on-droid" {nix = config.nix.package;})
        pkgs.bashInteractive
        pkgs.cacert
        pkgs.coreutils
        pkgs.less # since nix tools really want a pager available, #27
        config.nix.package
      ];

      path = pkgs.buildEnv {
        name = "nix-on-droid-path";

        paths = cfg.packages;

        inherit (cfg) extraOutputsToInstall;

        meta = {
          description = "Environment of packages installed through Nix-on-Droid.";
        };
      };
    };
  };
}
