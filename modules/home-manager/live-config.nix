# Config files that take effect on save, without a rebuild.
#
# They all live in `live/` at the repo root, and that folder is the whole
# set: a file outside it needs a switch. A program reaches its file through
# one stable link, `liveConfig.link`, which points at `<checkout>/live`.
# Nothing in the config names the checkout itself, so it can sit anywhere
# and move freely.
#
# Evaluation cannot see where the checkout is (a flake only knows its store
# copy), so the link has two writers:
#
#   - the `flake` command in shell/nushell.nix points it at the checkout it
#     just switched from, and reads it back to find that checkout again;
#   - the activation step below points it at the store copy of `live/`
#     whenever no checkout holds it: a fresh machine, a checkout that was
#     moved or deleted, or a host that never runs `flake` (droid). The files
#     are then current as of the last switch, just not editable in place.
{
  config,
  lib,
  ...
}: let
  cfg = config.liveConfig;
  storeCopy = "${../../live}";
in {
  options.liveConfig.link = lib.mkOption {
    type = lib.types.str;
    default = "${config.xdg.configHome}/nixos-live";
    readOnly = true;
    description = ''
      The stable link to the `live/` folder of the nixos checkout. Read it
      through `config.lib.liveConfig.source` rather than directly.
    '';
  };

  config = {
    # `source "helix/ignore"` for a home.file / xdg.configFile `source`.
    lib.liveConfig.source = path:
      config.lib.file.mkOutOfStoreSymlink "${cfg.link}/${path}";

    # A link into the store is replaced on every activation, since it names
    # the previous generation's copy. A link into a checkout that still
    # exists is the `flake` command's and is left alone.
    home.activation.liveConfigLink = lib.hm.dag.entryAfter ["writeBoundary"] ''
      link=${lib.escapeShellArg cfg.link}
      if [ ! -d "$link" ] || case "$(readlink -f -- "$link")" in /nix/store/*) true ;; *) false ;; esac; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$link")"
        $DRY_RUN_CMD ln -sfnT ${storeCopy} "$link"
      fi
    '';
  };
}
