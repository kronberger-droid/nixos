{host, ...}: {
  networking = {
    networkmanager = {
      enable = true;
      # Faster DNS resolution
      insertNameservers = ["1.1.1.1" "1.0.0.1" "8.8.8.8"];
      # Better connection management
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

    # Enable systemd-resolved for better DNS performance
    nameservers = ["1.1.1.1" "1.0.0.1"];
    # IPv6 privacy extensions
    enableIPv6 = true;
  };

  services.resolved = {
    enable = true;
    settings.Resolve.MulticastDNS = "no";
  };
  services.tailscale.enable = true;
}
