{lib, ...}: {
  # mkDefault so automatic-timezoned can null it on the workstations. The
  # homeserver keeps the fixed zone.
  time.timeZone = lib.mkDefault "Europe/Vienna";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "de_AT.UTF-8";
      LC_IDENTIFICATION = "de_AT.UTF-8";
      LC_MEASUREMENT = "de_AT.UTF-8";
      LC_MONETARY = "de_AT.UTF-8";
      LC_NAME = "de_AT.UTF-8";
      LC_NUMERIC = "de_AT.UTF-8";
      LC_PAPER = "de_AT.UTF-8";
      LC_TELEPHONE = "de_AT.UTF-8";
      LC_TIME = "de_AT.UTF-8";
    };
  };

  # man pages only. The doc and info trees are read by nothing installed
  # here, and documentation.nixos builds the NixOS manual plus the options
  # reference on every rebuild, which is the slow part and is online anyway.
  documentation = {
    enable = true;
    man.enable = true;
    doc.enable = false;
    info.enable = false;
    nixos.enable = false;
  };
}
