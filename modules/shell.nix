{ pkgs, ... }:
{
  programs.nushell = {
    enable = true;

		extraEnv = ''
			zoxide init nushell | save -f ~/.zoxide.nu
		'';
	
    extraConfig = ''
      # Source zoxide.nu if it exists
      if ($HOME/.zoxide.nu | path exists) {
        source $HOME/.zoxide.nu
      }

      # Disable banner
      $env.config.show_banner = false
    '';

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
      time = {
        disabled = false;
        format = "[$time]($style) ";
      };
    };
  };
}
