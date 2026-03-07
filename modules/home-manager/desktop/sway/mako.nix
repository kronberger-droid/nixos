{
  config,
  host,
  ...
}: {
  services = {
    mako = {
      enable = true;
      settings = {
        default-timeout = "10000";
        border-radius = "8";
        # Notifications: border base0D, background base00, text base05
        border-color = "#${config.scheme.base0D}";
        background-color = "#${config.scheme.base00}";
        text-color = "#${config.scheme.base05}";
        # High urgency: border base08
        "urgency=high" = {
          border-color = "#${config.scheme.base08}";
        };
        # Low urgency: border base03
        "urgency=low" = {
          border-color = "#${config.scheme.base03}";
        };
      };
    };
    poweralertd = {
      enable =
        if host == "spectre"
        then true
        else false;
    };
  };

  systemd.user.services.poweralertd = {
    Unit = {
      After = ["mako.service" "sway-session.target"];
      PartOf = ["sway-session.target"];
    };
  };
}
