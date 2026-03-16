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

      claude.mcpServers.inpdf = {
        command = "${pkgs.inpdf}/bin/inpdf";
        args = ["mcp"];
      };

      programs.arrabbiata-tui = {
        enable = true;
        configFile = "/run/secrets/arrabbiata-config";
      };

      # Set default terminal emulator
      terminal.emulator = "kitty";

      # Set primary compositor (both are always available via greetd)
      compositor.primary = primaryCompositor;

      services.gnome-keyring.enable = true;

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
          glib
          yazi
        ];
        stateVersion = "24.11";
      };
    };
  };
}
