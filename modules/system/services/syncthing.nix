{
  lib,
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

  # Patterns come from shared/ so this and the home-manager module, which
  # describe the same two folders, cannot drift apart. See that file for why
  # each pattern is there, and why they are not written out as files.
  ignores = import ../../shared/syncthing-ignores.nix;
in
  lib.mkIf enabled {
    services.syncthing = {
      enable = true;
      user = username;
      dataDir = homeDir;
      configDir = "${homeDir}/.config/syncthing";

      # A unix socket inside the 700 home rather than 127.0.0.1:8384, for the
      # reason in home-manager/apps/syncthing.nix: with no GUI password the
      # REST API is open to any local uid, the Claude Code sandbox included.
      # Web UI through ssh: `ssh -L 8384:${homeDir}/.config/syncthing/gui.sock
      # <host>`, then http://localhost:8384.
      guiAddress = "unix://${homeDir}/.config/syncthing/gui.sock";

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
            path = "${homeDir}/Documents/notes/general-vault";
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
