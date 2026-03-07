{lib, ...}: {
  systemd = {
    services = {
      NetworkManager-wait-online.enable = false;
      systemd-udev-settle.enable = false;
      # Remove fwupd from critical boot path - start it after boot completes
      fwupd = {
        before = lib.mkForce [];
        after = ["multi-user.target"];
      };
      # Disable serial console services
      "serial-getty@ttyS0".enable = false;
      "serial-getty@ttyS1".enable = false;
      "serial-getty@ttyS2".enable = false;
      "serial-getty@ttyS3".enable = false;
    };
    network.wait-online.enable = false;
  };

  services = {
    fwupd.enable = true;
    flatpak.enable = true;
    journald.extraConfig = ''
      Storage=persistent
      Compress=yes
      SystemMaxUse=1G
      RuntimeMaxUse=100M
    '';
  };
}
