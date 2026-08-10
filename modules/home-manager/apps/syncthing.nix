{
  config,
  lib,
  host,
  ...
}: let
  syncDevices = import ../../shared/syncthing-devices.nix;
  inherit (syncDevices) devices mobileDevices;

  # Patterns come from shared/ so this and the NixOS-level module, which
  # describe the same two folders, cannot drift apart. See that file for why
  # each pattern is there, and why they are not written out as files.
  ignores = import ../../shared/syncthing-ignores.nix;

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
            ignorePatterns = ignores.documents;
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
            ignorePatterns = ignores.generalVault;
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
