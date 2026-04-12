{
  host,
  lib,
  ...
}: {
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
    enableIPv6 = true;
  };

  # NetworkManager handles all networking; disable systemd-networkd to avoid
  # duplicate link management and spurious UP/DOWN log spam
  # PIA VPN module enables systemd-networkd; force off since NM handles everything
  systemd.network.enable = lib.mkForce false;

  services.resolved = {
    enable = true;
    settings.Resolve = {
      MulticastDNS = "no";
      FallbackDNS = "1.1.1.1 1.0.0.1 8.8.8.8";
    };
  };
  services.tailscale.enable = true;

  # Syncthing ports (service runs as user via Home Manager)
  networking.firewall = {
    allowedTCPPorts = [22000];
    allowedUDPPorts = [22000 21027];
  };
}
