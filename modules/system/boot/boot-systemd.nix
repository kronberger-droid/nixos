{
  lib,
  config,
  ...
}: {
  options.boot.systemd-boot-defaults.enable = lib.mkEnableOption "systemd-boot as the boot loader";

  # The menu settings hold for every host, whichever loader writes them:
  # lanzaboote (secureboot-tpm.nix) copies editor and timeout into loader.conf
  # and takes its generation limit from here. Only the loader itself hangs on
  # the option.
  config.boot.loader = {
    systemd-boot = {
      enable = lib.mkDefault config.boot.systemd-boot-defaults.enable;
      # With TPM auto-unlock, an editable cmdline (init=/bin/sh) is root on
      # the decrypted disk, which is the one thing Secure Boot exists to stop.
      editor = false;
      configurationLimit = lib.mkDefault 20;
    };
    # The default 5s on the menu, on every boot, is four too many.
    timeout = 1;
  };
}
