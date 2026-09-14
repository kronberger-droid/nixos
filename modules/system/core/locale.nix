{lib, ...}: {
  time.timeZone = "Europe/Vienna";

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

  # These are the NixOS defaults, stated for visibility. mkDefault so a
  # headless host (homeserver) can drop the doc and info trees.
  documentation = {
    enable = true;
    doc.enable = lib.mkDefault true;
    man.enable = true;
    info.enable = lib.mkDefault true;
  };
}
