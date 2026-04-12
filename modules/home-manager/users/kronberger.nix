{
  pkgs,
  inputs,
  host,
  isNotebook,
  primaryCompositor,
  ...
}: let
  dropkittenPkg = inputs.dropkitten.packages.${pkgs.stdenv.hostPlatform.system}.dropkitten;
in {
  home-manager = {
    extraSpecialArgs = {
      inherit inputs host isNotebook dropkittenPkg primaryCompositor;
    };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup-$(date +%Y%m%d-%H%M%S)";
    users.kronberger = {
      imports = [
        ../.
      ];

      # Claude Code
      claude.statusline.enable = true;
      claude.plugins = [
        "context7@claude-plugins-official"
        "github@claude-plugins-official"
        "explanatory-output-style@claude-plugins-official"
        "rust-analyzer-lsp@claude-plugins-official"
      ];
      claude.claudeMd = builtins.readFile ../apps/claude-md.md;
      claude.disableAutoMemory = true;

      claude.mcpServers.inpdf = {
        command = "${pkgs.inpdf}/bin/inpdf";
        args = ["mcp"];
      };

      claude.mcpServers.notal = {
        command = "${pkgs.notal}/bin/notal";
        args = ["--vault-path" "/home/kronberger/Documents/notes/general-vault/"];
      };

      programs.arrabbiata-tui = {
        enable = true;
        configFile = "/run/secrets/arrabbiata-config";
      };

      # Set default terminal emulator
      terminal.emulator = "kitty";

      # Set primary compositor (both are always available via greetd)
      compositor.primary = primaryCompositor;

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks."*" = {
          addKeysToAgent = "yes";
        };
      };

      home = {
        username = "kronberger";
        homeDirectory = "/home/kronberger";
        packages = with pkgs; [
          dropkittenPkg
          nemo-with-extensions
          yazi
          # Nix tooling (was in devShell)
          nixpkgs-fmt
          deadnix
          statix
          nix-tree
          nvd
          deploy-rs
        ];
        stateVersion = "24.11";
      };
    };
  };
}
