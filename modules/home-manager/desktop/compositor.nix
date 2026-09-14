{
  config,
  lib,
  ...
}: let
  cfg = config.compositor;
in {
  options.compositor = {
    primary = lib.mkOption {
      type = lib.types.enum ["sway" "niri"];
      default = "niri";
      # greetd's default session comes from the `primaryCompositor` specialArg
      # on the NixOS side (modules/system/desktop/greetd.nix), which is also
      # what users/kronberger.nix feeds into this option. Home-manager cannot
      # reach greetd, so this option only steers the home side: which
      # compositor's config is live and what XDG_CURRENT_DESKTOP says.
      description = "Primary compositor on the home-manager side.";
    };
  };

  config = {
    home.sessionVariables = {
      XDG_CURRENT_DESKTOP = cfg.primary;
    };
  };
}
