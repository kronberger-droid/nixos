{ pkgs, ... }:
{
  programs.nushell = {
    enable = true;

    # Write the zoxide init output to a file
    extraFiles."zoxide.nu" = {
      text = builtins.readFile "${pkgs.zoxide}/share/zoxide/init.nu";
    };

    # Add zoxide sourcing and other configurations
    extraConfig = ''
      # Source zoxide.nu
      source ~/.zoxide.nu

      # Disable banner
      $env.config.show_banner = false
    '';

    # Add shell aliases
    shellAliases = {
      cd = "zoxide";
      cat = "bat";
    };
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;

    # Add custom starship settings
    settings = (with builtins; fromTOML (readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml")) // {
      time = {
        disabled = false;
        format = "[$time]($style) ";
      };
    };
  };
}
