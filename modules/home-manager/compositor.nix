{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.compositor;
in {
  options.compositor = {
    primary = mkOption {
      type = types.enum ["sway" "niri"];
      default = "niri";
      description = "Primary compositor. Drives greetd default session.";
    };

    primaryCommand = mkOption {
      type = types.str;
      readOnly = true;
      description = "Command to launch the primary compositor (used by greetd).";
    };
  };

  config.compositor = {
    primaryCommand = mkDefault cfg.primary;
  };
}
