{
  pkgs,
  lib,
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
    ];
    config = {
      sway.default = ["wlr" "gtk"];
      niri = {
        default = ["gtk"];
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
    niri.package = pkgs.niri-unstable;
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
    # Avahi (mDNS/DNS-SD) disabled — not used for printers/casting on this network
    avahi.enable = false;
    # speech-dispatcher defaults to enabled in nixpkgs; disable explicitly
    speechd.enable = false;
    gvfs.enable = true;
    udisks2.enable = true;
    upower.enable = true;
  };

  # Mask Bluetooth OBEX file-transfer service (shipped by bluez, never used)
  systemd.user.services.obex.enable = lib.mkForce false;

  systemd.services.rfkill-unblock-bluetooth = {
    wantedBy = ["multi-user.target"];
    after = ["systemd-rfkill.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
    };
  };
}
