# modules/shell.nix            
{ pkgs, ... }:
{
	programs.nushell = {
		enable = true;
		extraConfig = ''
		  $env.config.show_banner = false
		'';
		shellAliases = {
			cd = "zoxide";
			cat = "bat";
		};
	};

	programs.starship = {
		enable = true;
		enableNushellIntegration = true;
		settings = (with builtins; fromTOML (readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml")) // {
		  time = {
		    disabled = false;
		    format = "[$time]($style) ";
		  };
		};
	};
}
