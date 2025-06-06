{ pkgs, ... }:
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
      icat = "kitten icat";
      c = "clear";
      e = "exit";
      "ga" = "git add";
      "gcm" = "git commit";
      "gps" = "git push";
      "gcl" = "git clone";
    };
  };
  
  programs.starship = {
    enable = true;
    enableNushellIntegration = true;

    # Add custom starship settings
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
