{
  config,
  pkgs,
  lib,
  inputs,
  host,
  isNotebook,
  hasAccelerometer,
  username,
  ...
}: let
  dropkittenPkg = inputs.dropkitten.packages.${pkgs.stdenv.hostPlatform.system}.dropkitten;
in {
  home-manager = {
    extraSpecialArgs = {
      inherit inputs host isNotebook hasAccelerometer dropkittenPkg;
    };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup-$(date +%Y%m%d-%H%M%S)";
    users.${username} = {
      imports = [
        ../.
        # Claude Code config shared with the homeserver — see that file for why
        # it is imported by path rather than through apps/default.nix.
        ../apps/claude-settings.nix
      ];

      # TU coLAB (Confluence Data Center 10.2) for Claude Code, read-only.
      # Here rather than in claude-settings.nix: the token is this user's,
      # and the sandbox account and the homeserver must not get the server.
      #
      # The token never enters ~/.claude.json: mcp-atlassian runs
      # CONFLUENCE_PERSONAL_TOKEN_COMMAND at start and reads the agenix file
      # itself. READ_ONLY_MODE is the server's promise, not colab's: a PAT
      # carries all of its owner's rights, so the token's expiry is the
      # real limit.
      #
      # Not in nixpkgs, hence uvx with a pinned version, fetched from PyPI
      # on first start. uv's own Python downloads are dynamically linked
      # and do not run on NixOS, so it gets nixpkgs' interpreter instead.
      claude.mcpServers.colab = lib.mkIf (config.age.secrets ? colab-token) {
        command = "${pkgs.uv}/bin/uvx";
        args = ["mcp-atlassian@0.24.6"];
        env = {
          CONFLUENCE_URL = "https://colab.tuwien.ac.at";
          CONFLUENCE_PERSONAL_TOKEN_COMMAND = "cat ${config.age.secrets.colab-token.path}";
          READ_ONLY_MODE = "true";
          UV_PYTHON = "${pkgs.python3}/bin/python3";
          UV_PYTHON_DOWNLOADS = "never";
        };
      };

      # The one terminal that gets installed and configured (terminals/*.nix
      # are gated on this).
      terminal.emulator = "rio";

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings =
          {
            "*" = {
              addKeysToAgent = "yes";
            };
            # Cluster logins. These used to live in a nushell `connect`
            # function, which only worked from nushell; as ssh_config hosts
            # they serve scp, rsync, nix copy and git too.
            datalab = {
              HostName = "cluster.datalab.tuwien.ac.at";
              User = "martin.kronberger";
            };
            asc4 = {
              HostName = "vsc4.vsc.ac.at";
              User = "sumo_mk";
            };
            asc5 = {
              HostName = "vsc5.vsc.ac.at";
              User = "sumo_mk";
            };
          }
          # `homeserver` resolves through Tailscale's MagicDNS, so it needs an
          # entry only for the key. On a host with an admin key
          # (shared/ssh-admin-keys.nix) every login there, deploy-rs and
          # nix-remote included, signs with that key from disk and never asks
          # the agent. The control master makes a deploy's several connections
          # cost one passphrase. While it lingers, any local process can ride
          # it without one, so it lingers only as long as a deploy needs.
          // lib.optionalAttrs (builtins.hasAttr host (import ../../shared/ssh-admin-keys.nix)) {
            homeserver = {
              IdentityFile = "~/.ssh/id_ed25519_admin";
              IdentitiesOnly = "yes";
              IdentityAgent = "none";
              AddKeysToAgent = "no";
              ControlMaster = "auto";
              ControlPath = "~/.ssh/cm-%C";
              ControlPersist = "2m";
            };
          };
      };

      home = {
        inherit username;
        homeDirectory = "/home/${username}";
        # One home for each package: statix/deadnix live with the Nix LSP
        # set in editors/helix.nix.
        packages = with pkgs; [
          dropkittenPkg
          # `claude-math`: claude with the math pane mod loaded. Desktop only,
          # since the pane draws images and the headless accounts have no
          # terminal to show them in.
          inputs.claude-mathpane.packages.${pkgs.stdenv.hostPlatform.system}.default
          nemo-with-extensions
          # Nix tooling (was in devShell)
          nix-tree
          nvd
          deploy-rs
        ];
        stateVersion = "26.11";
      };
    };
  };
}
