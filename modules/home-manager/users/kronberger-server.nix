{
  pkgs,
  inputs,
  username,
  ...
}: let
  # The shell setup both login accounts share: ${username} and the phone's
  # `droid` (hosts/homeserver/configuration.nix).
  shellModules = [
    ../shell/nushell.nix
    ../shell/git.nix
    ../shell/tools.nix
    ../terminals/zellij-server.nix
    ../theming/base16-scheme.nix
  ];
  homeFor = user: {
    username = user;
    homeDirectory = "/home/${user}";
    stateVersion = "26.11";
  };
in {
  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.${username} = {
      imports =
        shellModules
        ++ [
          # Same Claude Code config the desktops get: statusline, plugins,
          # CLAUDE.md and the skill set. This host imports modules individually
          # rather than the whole tree, so the path is explicit.
          ../apps/claude-settings.nix
        ];

      home = homeFor username;

      programs.home-manager.enable = true;
    };

    # No Claude Code config: from the phone, Claude runs in the sandbox
    # account through Remote Control, never as droid.
    users.droid = {
      imports = shellModules;
      home = homeFor "droid";
      programs.home-manager.enable = true;
    };
  };
}
