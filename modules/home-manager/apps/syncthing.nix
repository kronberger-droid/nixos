{
  config,
  lib,
  host,
  ...
}: let
  syncDevices = import ../../shared/syncthing-devices.nix;
  inherit (syncDevices) devices mobileDevices;

  enabled = builtins.hasAttr host devices;

  otherDevices =
    lib.filterAttrs (name: _: name != host) devices;

  allPeerDevices = otherDevices // mobileDevices;
in
  lib.mkIf enabled {
    services.syncthing = {
      enable = true;

      # Let Nix manage devices; allow adding folders via UI too
      overrideDevices = true;
      overrideFolders = false;

      settings = {
        devices = allPeerDevices;

        folders = {
          "documents" = {
            path = "~/Documents";
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
            path = config.vault.path;
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
          urAccepted = -1;
          relaysEnabled = true;
          localAnnounceEnabled = true;
          globalAnnounceEnabled = true;
        };
      };
    };
  }
