{
  lib,
  host,
  ...
}: let
  # Device IDs — fill these in after first start on each machine
  # Get with: syncthing -device-id (or from the web UI)
  devices = {
    homeserver = {
      id = "TFHHQZC-OZCHJDU-SVETB4J-2LNTROX-FYJZFT5-BG2LG2X-CIRCEEZ-LLRVFAR";
      addresses = ["tcp://192.168.2.54:22000" "tcp://100.92.46.97:22000" "dynamic"];
    };
    spectre = {
      id = "4RZB52C-SF37CKE-IUGTFM4-HZYF76P-55RKI4G-NYAE5SZ-GVRW2DP-SGSWJAK";
      addresses = ["tcp://100.83.89.128:22000" "dynamic"];
    };
    intelNuc = {
      id = "UKYT4BM-RHAHSKP-3EW3QRN-USWUMRL-MC56REB-AM4JDPZ-GLY3QW5-XRKW4QI";
      addresses = ["tcp://100.64.13.9:22000" "dynamic"];
    };
  };

  # Mobile devices — not NixOS-managed, only added as peers
  mobileDevices = {
    nothing-phone = {
      id = "EIB56A6-BLR43CP-N6243GG-NNI6S3B-OFVE2NO-BA3QYZW-YPG5CUD-CEJTXA7";
      addresses = ["dynamic"];
    };
  };

  # Only enable on hosts that are in the devices list
  enabled = builtins.hasAttr host devices;

  # Which NixOS devices each host syncs with
  otherDevices =
    lib.filterAttrs (name: _: name != host) devices;

  # All peers including mobile
  allPeerDevices = otherDevices // mobileDevices;
in
  lib.mkIf enabled {
    services.syncthing = {
      enable = true;
      user = "kronberger";
      dataDir = "/home/kronberger";
      configDir = "/home/kronberger/.config/syncthing";

      # Localhost only — access remote UIs via SSH tunnel:
      # ssh -L 8384:127.0.0.1:8384 kronberger@<host>
      guiAddress = "127.0.0.1:8384";

      # Let Nix manage devices; allow adding folders via UI too
      overrideDevices = true;
      overrideFolders = false;

      settings = {
        devices = allPeerDevices;

        folders = {
          # Documents — synced across all NixOS machines
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

          # Obsidian vault — synced to phone too
          "general-vault" = {
            path = "/home/kronberger/Documents/notes/general-vault";
            devices = builtins.attrNames otherDevices ++ builtins.attrNames mobileDevices;
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
          relaysEnabled = true;
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
