{ config, host, ... }:
{
  services = {
    mako = {
      enable = true;
      settings = {
        default-timeout = "10000";
        border-radius = "8";
        border-color = config.myTheme.accentColor;
        background-color = config.myTheme.backgroundColor;
      };
    };
    poweralertd.enable = if host == "spectre" then true else false;
  };
}
