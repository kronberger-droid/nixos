{
  pkgs,
  lib,
  inputs,
  host,
  isNotebook,
  hasAccelerometer,
  primaryCompositor,
  username,
  ...
}: let
  dropkittenPkg = inputs.dropkitten.packages.${pkgs.stdenv.hostPlatform.system}.dropkitten;
in {
  home-manager = {
    extraSpecialArgs = {
      inherit inputs host isNotebook hasAccelerometer dropkittenPkg primaryCompositor;
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

      # Desktop-only: inpdf comes from the overlay in system/core/packages.nix,
      # which the homeserver does not import, so it cannot live in the shared file.
      claude.mcpServers.inpdf = {
        command = "${pkgs.inpdf}/bin/inpdf";
        args = ["mcp"];
      };

      # The one terminal that gets installed and configured (terminals/*.nix
      # are gated on this).
      terminal.emulator = "rio";

      # The one compositor that gets configured and offered by greetd. The
      # value comes from mkHost so the NixOS and home sides agree.
      compositor.primary = primaryCompositor;

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings = {
          "*" = {
            addKeysToAgent = "yes";
          };
          # Cluster logins. These used to live in a nushell `connect`
          # function, which only worked from nushell; as ssh_config hosts
          # they serve scp, rsync, nix copy and git too. `homeserver` needs
          # no entry: it resolves through Tailscale's MagicDNS.
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
        };
      };

      home = {
        inherit username;
        homeDirectory = "/home/${username}";
        # One home for each package: statix/deadnix live with the Nix LSP
        # set in editors/helix.nix, pandoc with aerc's compose pipeline.
        packages = with pkgs; [
          dropkittenPkg
          nemo-with-extensions
          # Nix tooling (was in devShell)
          nixpkgs-fmt
          nix-tree
          nvd
          deploy-rs
        ];
        stateVersion = "24.11";
        # HM master bumped its release string to 26.11 ahead of nixpkgs
        # unstable (still 26.05) during the 26.05 changeover. Both inputs
        # track unstable and HM follows nixpkgs, so there is no real
        # mismatch — silence the false-positive warning.
        enableNixpkgsReleaseCheck = false;
      };
    };
  };
}
