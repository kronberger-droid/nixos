# Vendored & patched copy of nix-on-droid's modules/environment/login
# (rev 55b6449b, the flake.lock pin), swapped in via disabledModules below.
# login.nix / login-inner.nix are reused from the input unchanged; only this
# default.nix is replicated, to change which proot-static gets installed.
#
# Why: upstream pins proot-termux unstable-2024-05-04. On this phone that
# build cannot allocate build pseudoterminals — every local derivation build
# dies with "error: getting pseudoterminal attributes: Permission denied"
# (tcgetattr on the pty master in Nix's builder setup). The device ran an
# older proot for months (the installProotStatic activation step is ordered
# AFTER installPackages, which always failed, so the 2024-05-04 binary was
# never installed) and local builds worked the whole time. The first switch
# that got past installPackages staged the new proot; the next app restart
# swapped it in, and from then on even trivial writeText derivations failed
# to build. Pin the previous proot (unstable-2023-11-11, what nix-on-droid
# shipped before commit 35076ea) to get building working again.
#
# The store path is substituted from https://nix-on-droid.cachix.org (a
# default substituter on-device) before the copy, since these cross-compiled
# paths are referenced by string and are not part of the generation closure.
#
# Drop this file (and its import in nix-on-droid.nix) if a future
# nix-on-droid pin ships a proot that handles build ptys on this device.
{
  config,
  lib,
  pkgs,
  inputs,
  initialPackageInfo,
  targetSystem,
  ...
}:
with lib; let
  cfg = config.environment.files;

  loginDir = "${inputs.nix-on-droid}/modules/environment/login";

  login = pkgs.callPackage "${loginDir}/login.nix" {inherit config;};

  loginInner = pkgs.callPackage "${loginDir}/login-inner.nix" {
    inherit config initialPackageInfo targetSystem;
  };
in {
  disabledModules = [loginDir "${loginDir}/default.nix"];

  ###### interface (upstream-verbatim)

  options = {
    environment.files = {
      login = mkOption {
        type = types.package;
        readOnly = true;
        internal = true;
        description = "Login script.";
      };

      loginInner = mkOption {
        type = types.package;
        readOnly = true;
        internal = true;
        description = "Login-inner script.";
      };

      prootStatic = mkOption {
        type = types.package;
        readOnly = true;
        internal = true;
        description = "<literal>proot-static</literal> package.";
      };
    };
  };

  ###### implementation

  config = {
    build.activation = {
      # upstream-verbatim
      installLogin = ''
        if ! diff /bin/login ${login} > /dev/null; then
          $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents /bin
          $DRY_RUN_CMD cp $VERBOSE_ARG ${login} /bin/.login.tmp
          $DRY_RUN_CMD chmod $VERBOSE_ARG u+w /bin/.login.tmp
          $DRY_RUN_CMD mv $VERBOSE_ARG /bin/.login.tmp /bin/login
        fi
      '';

      # upstream-verbatim
      installLoginInner = ''
        if (test -e /usr/lib/.login-inner.new && ! diff /usr/lib/.login-inner.new ${loginInner} > /dev/null) || \
            (! test -e /usr/lib/.login-inner.new && ! diff /usr/lib/login-inner ${loginInner} > /dev/null); then
          $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents /usr/lib
          $DRY_RUN_CMD cp $VERBOSE_ARG ${loginInner} /usr/lib/.login-inner.tmp
          $DRY_RUN_CMD chmod $VERBOSE_ARG u+w /usr/lib/.login-inner.tmp
          $DRY_RUN_CMD mv $VERBOSE_ARG /usr/lib/.login-inner.tmp /usr/lib/.login-inner.new
        fi
      '';

      # upstream-verbatim except the substitution guard: the pinned proot is
      # referenced by string (no store context), so make sure it exists in the
      # local store before copying from it.
      installProotStatic = ''
        if ! test -e ${cfg.prootStatic}/bin/proot-static; then
          $DRY_RUN_CMD nix-store --realise ${cfg.prootStatic} > /dev/null
        fi
        if (test -e /bin/.proot-static.new && ! diff /bin/.proot-static.new ${cfg.prootStatic}/bin/proot-static > /dev/null) || \
            (! test -e /bin/.proot-static.new && ! diff /bin/proot-static ${cfg.prootStatic}/bin/proot-static > /dev/null); then
          $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents /bin
          $DRY_RUN_CMD cp $VERBOSE_ARG ${cfg.prootStatic}/bin/proot-static /bin/.proot-static.tmp
          $DRY_RUN_CMD chmod $VERBOSE_ARG u+w /bin/.proot-static.tmp
          $DRY_RUN_CMD mv $VERBOSE_ARG /bin/.proot-static.tmp /bin/.proot-static.new
        fi
      '';
    };

    environment.files = {
      inherit login loginInner;

      # unstable-2023-11-11, the pin upstream used before 2024-05-04 — the
      # last proot known to handle Nix build ptys on this device.
      prootStatic = let
        crossCompiledPaths = {
          aarch64-linux = "/nix/store/phj07a1pg3vwqdhq4cxd1dac4zc28mnc-proot-termux-static-aarch64-unknown-linux-android-unstable-2023-11-11";
          x86_64-linux = "/nix/store/kg1bfwprdlf28fqd7ml86fywshkvcbhl-proot-termux-static-x86_64-unknown-linux-android-unstable-2023-11-11";
        };
      in "${crossCompiledPaths.${targetSystem}}";
    };
  };
}
