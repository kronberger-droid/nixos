{
  lib,
  pkgs,
  config,
  host,
  username,
  ...
}: let
  syncDevices = import ../../shared/syncthing-devices.nix;
  inherit (syncDevices) devices mobileDevices;

  # The user's home, taken from the NixOS account definition rather than
  # rebuilt from a string, so it tracks any users.users.<name>.home override.
  homeDir = config.users.users.${username}.home;

  # Only enable on hosts that are in the devices list
  enabled = builtins.hasAttr host devices;

  # Which NixOS devices each host syncs with
  otherDevices =
    lib.filterAttrs (name: _: name != host) devices;

  # All peers including mobile
  allPeerDevices = otherDevices // mobileDevices;

  # The vault is synced as its own Syncthing folder, so exclude it from
  # the parent `documents` folder to avoid double-indexing every change.
  documentsIgnore = pkgs.writeText "documents-stignore" ''
    notes/general-vault
  '';
in
  lib.mkIf enabled {
    services.syncthing = {
      enable = true;
      user = username;
      dataDir = homeDir;
      configDir = "${homeDir}/.config/syncthing";

      # Localhost only — access remote UIs via SSH tunnel:
      # ssh -L 8384:127.0.0.1:8384 <user>@<host>
      guiAddress = "127.0.0.1:8384";

      # Let Nix manage devices; allow adding folders via UI too
      overrideDevices = true;
      overrideFolders = false;

      settings = {
        devices = allPeerDevices;

        folders = {
          # Documents — synced across all NixOS machines
          "documents" = {
            path = "${homeDir}/Documents";
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
            path = "${homeDir}/Documents/notes/general-vault";
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

    systemd.tmpfiles.rules = [
      "L+ ${homeDir}/Documents/.stignore - - - - ${documentsIgnore}"
    ];

    # Open firewall for Syncthing
    networking.firewall = {
      allowedTCPPorts = [22000]; # Sync protocol
      allowedUDPPorts = [22000 21027]; # Sync + discovery
    };
  }
