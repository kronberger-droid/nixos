{
  pkgs,
  host,
  ...
}: let
  outputNames = {
    intelNuc = "HDMI-A-1";
    t480s = "eDP-1";
    spectre = "eDP-1";
    portable = "*";
  };
  outputName = outputNames.${host} or (throw "Unknown hostname: ${host}");
in {
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      sway.default = ["wlr" "gtk"];
      niri = {
        default = ["gnome" "gtk"];
        "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
      };
    };
    wlr = {
      enable = true;
      settings = {
        screencast = {
          output_name = outputName;
          max_fps = 60;
          chooser_type = "simple";
          chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -or";
        };
      };
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;

  programs = {
    niri.enable = true;
    xwayland.enable = true;
    dconf.enable = true;
    seahorse.enable = true;
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = false;
    };
    firmware = [pkgs.linux-firmware];
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
    };
    gvfs.enable = true;
    udisks2.enable = true;
    upower.enable = true;
  };
}
