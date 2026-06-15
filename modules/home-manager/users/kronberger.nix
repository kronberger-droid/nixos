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
      ];
      claude.claudeMd = builtins.readFile ../apps/claude-md.md;

      claude.skills.rust-to-cpp.content = builtins.readFile ../apps/skills/rust-to-cpp.md;
      claude.skills.vault.content = builtins.readFile ../apps/skills/vault.md;

      claude.mcpServers.inpdf = {
        command = "${pkgs.inpdf}/bin/inpdf";
        args = ["mcp"];
      };

      # Set default terminal emulator
      terminal.emulator = "rio";

      # Set primary compositor (both are always available via greetd)
      compositor.primary = primaryCompositor;

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings."*" = {
          addKeysToAgent = "yes";
        };
      };

      home = {
        username = "kronberger";
        homeDirectory = "/home/kronberger";
        packages = with pkgs; [
          dropkittenPkg
          nemo-with-extensions
          # Nix tooling (was in devShell)
          nixpkgs-fmt
          deadnix
          statix
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
