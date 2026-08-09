{
  pkgs,
  inputs,
  username,
  ...
}: {
  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.${username} = {
      imports = [
        ../shell/nushell.nix
        ../shell/git.nix
        ../shell/tools.nix
        ../terminals/zellij-server.nix
        ../theming/base16-scheme.nix
        # Same Claude Code config the desktops get: statusline, plugins,
        # CLAUDE.md and the skill set. This host imports modules individually
        # rather than the whole tree, so the path is explicit.
        ../apps/claude-settings.nix
      ];

      home = {
        inherit username;
        homeDirectory = "/home/${username}";
        stateVersion = "25.05";
      };

      programs.home-manager.enable = true;
    };
  };
}
