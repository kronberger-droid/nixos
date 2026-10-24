{
  lib,
  pkgs,
  ...
}: {
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      niri = {
        default = ["gtk"];
        "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
        # gnome backend implements niri's per-window screencast picker;
        # gtk has no ScreenCast impl, so window sharing (Helium/Teams) needs this.
        "org.freedesktop.impl.portal.ScreenCast" = ["gnome"];
        "org.freedesktop.impl.portal.Screenshot" = ["gnome"];
        # Same story for Clipboard and the RemoteDesktop session it rides on:
        # gtk implements neither, and Bitwarden falls back to them whenever its
        # X11 clipboard backend is unavailable.
        "org.freedesktop.impl.portal.RemoteDesktop" = ["gnome"];
        "org.freedesktop.impl.portal.Clipboard" = ["gnome"];
        # This file replaces the niri-portals.conf niri ships, so its Secret
        # line has to be restated. Without it oo7-portal runs but is never
        # routed to (its .portal says UseIn=gnome, ignored once a conf exists).
        "org.freedesktop.impl.portal.Secret" = ["oo7-portal"];
      };
    };
  };

  # nixpkgs wraps every Electron/Chromium app so that this variable, and only
  # this variable, adds the ozone Wayland flags. Without it they all default to
  # X11 and run through xwayland-satellite. Set at the system level so it lands
  # in the PAM environment, which greetd's niri-session inherits.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # veila (modules/home-manager/desktop/veila.nix) authenticates against a
  # service named after itself and falls back to system-auth, which NixOS does
  # not have, so without this entry no password would ever unlock it.
  security.pam.services.veila = {};

  programs = {
    # Every workstation runs Steam; each host only sets its own client flags
    # through programs.steam.package (intelNuc, profiles/secureboot-laptop).
    steam = {
      enable = true;
      gamescopeSession.enable = true;
      extraPackages = [pkgs.sdl3];
    };
    niri.enable = true;
    niri.package = pkgs.niri-unstable;
    xwayland.enable = true;
    dconf.enable = true;
    seahorse.enable = true;
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = lib.mkDefault false;
    };
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
    # For the Flathub apps in home-manager/apps/flatpak.nix.
    flatpak.enable = true;
  };

  systemd.services.rfkill-unblock-bluetooth = {
    wantedBy = ["multi-user.target"];
    after = ["systemd-rfkill.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
    };
  };
}
