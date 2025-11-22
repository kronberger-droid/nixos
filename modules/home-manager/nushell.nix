{pkgs, ...}: {
  home.packages = with pkgs; [
    bat
    zoxide
    lazygit
    rip2
    navi
    tealdeer
    zellij
  ];
  programs.nushell = {
    enable = true;

    extraEnv = builtins.readFile ./nushell/extra_env.nu;

    extraConfig = builtins.readFile ./nushell/extra_config.nu;

    shellAliases = {
      cd = "z";
      cat = "bat";
      icat = "kitten icat";
      ssh = "kitty +kitten ssh";
      rip = "rip --graveyard ($env.HOME)/.local/share/Trash";
      rm = "echo 'use rip instead'";
      tldr = "tealdeer";
    };
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;

    settings =
      (with builtins; fromTOML (readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml"))
      // {
        command_timeout = 2000;
        git_branch.symbol = " ";
        time = {
          disabled = false;
          format = "[$time]($style) ";
        };
      };
  };
}
