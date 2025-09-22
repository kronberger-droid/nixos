{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bat
    zoxide
    rip2
  ];
  programs.nushell = {
    enable = true;

    extraEnv = builtins.readFile ./nushell/extra_env.nu;

    extraConfig = builtins.readFile ./nushell/extra_config.nu;

    shellAliases = {
      cd = "z";
      cat = "bat";
      icat = "kitten icat";
      rip = "rip --graveyard ($env.HOME)/.local/share/Trash/files";
      rm = "echo 'use rip instead'";
    };
  };
  
  programs.starship = {
    enable = true;
    enableNushellIntegration = true;

    settings = (with builtins; fromTOML (readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml")) // {
      command_timeout = 2000;
      git_branch.symbol = " ";
      time = {
        disabled = false;
        format = "[$time]($style) ";
      };
    };
  };
}
