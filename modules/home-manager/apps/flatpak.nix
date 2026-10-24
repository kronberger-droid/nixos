# Apps that run better from Flathub than from a nixpak wrapper: they bundle
# their own toolkits and expect the Flatpak runtime around them. nix-flatpak
# installs them per user from a systemd unit on activation, so the bits come
# from Flathub, not the store, and are not covered by rollbacks.
#
# The system side (services.flatpak.enable) is in system/desktop/desktop.nix;
# this module turns itself on from that.
_: {
  services.flatpak = {
    packages = [
      # The nixpak attempt crashed inside its bundled Qt and CEF once nested
      # in a second sandbox.
      "org.onlyoffice.desktopeditors"
      # On trial next to programs.steam (desktop.nix). Its home is a private
      # ~/.var/app/com.valvesoftware.Steam, so games do not see ~/.ssh or
      # the rest of $HOME.
      "com.valvesoftware.Steam"
    ];

    overrides = {
      # Flathub grants filesystem=host and the network. It parses untrusted
      # documents and runs their macros and plugins, so it gets neither:
      # only the folders documents live in, and no way to send anything.
      "org.onlyoffice.desktopeditors".Context = {
        shared = ["!network"];
        filesystems = ["!host" "!/tmp" "xdg-documents" "xdg-download"];
      };
    };

    # Flathub ships security fixes on its own schedule, so pull them weekly
    # rather than only when the config changes.
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
