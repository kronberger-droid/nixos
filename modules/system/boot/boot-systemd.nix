{
  lib,
  config,
  ...
}: {
  options.boot.systemd-boot-defaults.enable = lib.mkEnableOption "standard systemd-boot config";

  config = lib.mkMerge [
    # systemd initrd is used by both systemd-boot and lanzaboote
    { boot.initrd.systemd.enable = lib.mkDefault true; }

    (lib.mkIf config.boot.systemd-boot-defaults.enable {
      boot.loader = {
        systemd-boot = {
          enable = true;
          editor = false;
          configurationLimit = 20;
        };
        timeout = 1;
      };
    })
  ];
}
