{
  config,
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
    niri.enable = true;
    niri.package = pkgs.niri-unstable;
    xwayland.enable = true;
    dconf.enable = true;
    seahorse.enable = true;
  };

  # niri-flake hardcodes polkit-kde-agent as the authentication agent, with
  # no option to pick another: KDE Frameworks and breeze-icons for one
  # password dialog. soteria is the same agent on GTK 4, which ironbar and
  # loupe already keep in the closure.
  systemd.user.services.niri-flake-polkit.serviceConfig.ExecStart =
    lib.mkForce "${pkgs.soteria}/bin/soteria";

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = lib.mkDefault false;
    };
    # No 32-bit stack: Steam is the Flathub build and brings its own
    # Platform.GL32 and Compat.i386, and nothing native here is 32-bit (no
    # wine, no lutris). enable32Bit was a second mesa and llvm, about 1G.
    graphics.enable = true;
  };

  services = {
    # Avahi (mDNS/DNS-SD) disabled — not used for printers/casting on this network
    avahi.enable = false;
    # speech-dispatcher defaults to enabled in nixpkgs; disable explicitly
    speechd.enable = false;
    # Nemo needs gvfs for trash://, the removable-drive sidebar (udisks2
    # volume monitor) and MTP. The module default is pkgs.gnome.gvfs, which
    # drags in gnome-online-accounts, libmsgraph and the OneDrive backend for
    # a cloud-accounts daemon that nothing here runs. The plain build keeps
    # everything Nemo uses and drops the GOA half. samba stays: vlc links it
    # too, so overriding it out of gvfs alone would cost smb:// in Nemo and
    # a local gvfs build per nixpkgs bump without freeing a byte.
    gvfs = {
      enable = true;
      package = pkgs.gvfs;
    };
    udisks2.enable = true;
    upower.enable = true;
    # For the Flathub apps in home-manager/apps/flatpak.nix.
    flatpak.enable = true;
  };

  # Steam is the Flathub build. programs.steam used to bring the udev rules
  # for controllers and the Steam Deck; the Flatpak cannot install them.
  # Hosts set their client flags through steamFlatpak.extraArgs
  # (home-manager/apps/steam.nix).
  hardware.steam-hardware.enable = true;

  systemd.services =
    {
      rfkill-unblock-bluetooth = {
        wantedBy = ["multi-user.target"];
        after = ["systemd-rfkill.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
        };
      };
    }
    # Home Manager activation at boot runs before any session bus exists, so
    # dconfSettings wraps dconf in a throwaway dbus-run-session. dconf 51
    # (glib 2.90) activates gvfsd on that bus; its gvfsd-fuse mounts ~/.gvfs
    # for want of XDG_RUNTIME_DIR and segfaults when the bus goes away. The
    # core dump then holds the mount for systemd-coredump's five minutes, and
    # ironbar and rio hang on it until it is killed. Nothing in activation
    # needs gvfs, so GIO stays on the local VFS there.
    // lib.mapAttrs' (user: _:
      lib.nameValuePair "home-manager-${user}" {
        environment.GIO_USE_VFS = "local";
      })
    config.home-manager.users;
}
