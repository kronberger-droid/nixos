{
  lib,
  config,
  ...
}: {
  options.boot.systemd-boot-defaults.enable = lib.mkEnableOption "standard systemd-boot config";

  config = lib.mkIf config.boot.systemd-boot-defaults.enable {
    boot.initrd.systemd.enable = true;
    boot.loader = {
      systemd-boot = {
        enable = true;
        editor = false;
        configurationLimit = 20;
      };
      timeout = 1;
    };
  };
}
