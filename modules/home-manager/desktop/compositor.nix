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
      description = "Primary compositor. Drives greetd default session.";
    };

    primaryCommand = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Command to launch the primary compositor (used by greetd).";
    };
  };

  config = {
    compositor.primaryCommand = lib.mkDefault cfg.primary;

    home.sessionVariables = {
      XDG_CURRENT_DESKTOP = cfg.primary;
    };
  };
}
