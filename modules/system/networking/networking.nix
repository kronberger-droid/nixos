{host, lib, ...}: {
  networking = {
    networkmanager = {
      enable = lib.mkDefault true;
      settings = {
        main = {
          dns = "systemd-resolved";
          rc-manager = "symlink";
        };
        device = {
          "wifi.scan-rand-mac-address" = "yes";
        };
        connection = {
          "wifi.cloned-mac-address" = "stable";
          "ethernet.cloned-mac-address" = "stable";
        };
      };
    };
    hostName = host;

    stevenblack = {
      enable = true;
      block = ["porn"];
    };

    enableIPv6 = true;
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      MulticastDNS = "no";
      FallbackDNS = "1.1.1.1 1.0.0.1 8.8.8.8";
    };
  };
  services.tailscale.enable = true;
}
