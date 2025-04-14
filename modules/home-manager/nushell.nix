{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    bat
    zoxide
  ];
  programs.nushell = {
    enable = true;

    extraEnv = builtins.readFile ./nushell/extra_env.nu;

    extraConfig = builtins.readFile ./nushell/extra_config.nu;

    # Add shell aliases
    shellAliases = {
      cd = "z";
      cat = "bat";
    };
  };
  
  programs.starship = {
    enable = true;
    enableNushellIntegration = true;

    # Add custom starship settings
    settings = (with builtins; fromTOML (readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml")) // {
      command_timeout = 2000;  # Global timeout (2 seconds for all commands)
      git_branch.symbol = " ";
      time = {
        disabled = false;
        format = "[$time]($style) ";
      };
    };
  };
}
