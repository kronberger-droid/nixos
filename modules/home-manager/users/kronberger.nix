{
  pkgs,
  lib,
  inputs,
  host,
  isNotebook,
  primaryCompositor,
  username,
  ...
}: let
  dropkittenPkg = inputs.dropkitten.packages.${pkgs.stdenv.hostPlatform.system}.dropkitten;

  # Matt Pocock's skills, derived straight from the repo's plugin manifest so
  # the set tracks upstream exactly (a flake update adds/removes skills with it).
  # plugin.json lists relative paths like "./skills/engineering/tdd"; we map each
  # to { <foldername> = <store path to that folder>; } for claude.skillDirs.
  mattSkills = let
    manifest = builtins.fromJSON (builtins.readFile "${inputs.mattpocock-skills}/.claude-plugin/plugin.json");
    toEntry = rel: let
      clean = lib.removePrefix "./" rel;
    in
      lib.nameValuePair (builtins.baseNameOf clean) (inputs.mattpocock-skills + "/${clean}");
  in
    builtins.listToAttrs (map toEntry manifest.skills);
in {
  home-manager = {
    extraSpecialArgs = {
      inherit inputs host isNotebook dropkittenPkg primaryCompositor;
    };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup-$(date +%Y%m%d-%H%M%S)";
    users.${username} = {
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

      # Matt Pocock's skills collection (github:mattpocock/skills), whole-folder
      # symlinked into ~/.claude/skills/. See mattSkills above for derivation.
      claude.skillDirs = mattSkills;

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
        inherit username;
        homeDirectory = "/home/${username}";
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
