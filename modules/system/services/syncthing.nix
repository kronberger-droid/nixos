{
  config,
  lib,
  host,
  ...
}: let
  # Device IDs — fill these in after first start on each machine
  # Get with: syncthing -device-id (or from the web UI)
  devices = {
    homeserver = {
      id = "REPLACE-ME";
      addresses = ["tcp://192.168.2.54:22000" "dynamic"];
    };
    spectre = {
      id = "REPLACE-ME";
      addresses = ["dynamic"];
    };
    intelNuc = {
      id = "REPLACE-ME";
      addresses = ["dynamic"];
    };
  };

  # Which devices each host syncs with
  otherDevices =
    lib.filterAttrs (name: _: name != host) devices;

  isServer = host == "homeserver";
in {
  services.syncthing = {
    enable = true;
    user = "kronberger";
    dataDir = "/home/kronberger";
    configDir = "/home/kronberger/.config/syncthing";

    # Let Nix manage devices; allow adding folders via UI too
    overrideDevices = true;
    overrideFolders = false;

    settings = {
      devices = otherDevices;

      folders = {
        # Documents — synced everywhere
        "documents" = {
          path = "/home/kronberger/Documents";
          devices = builtins.attrNames otherDevices;
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "2592000"; # 30 days
            };
          };
        };
      };

      options = {
        urAccepted = -1; # Disable usage reporting
        relaysEnabled = !isServer;
        localAnnounceEnabled = true;
        globalAnnounceEnabled = true;
      };
    };
  };

  # Open firewall for Syncthing
  networking.firewall = {
    allowedTCPPorts = [22000]; # Sync protocol
    allowedUDPPorts = [22000 21027]; # Sync + discovery
  };
}
