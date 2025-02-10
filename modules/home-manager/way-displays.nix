{ config, lib, pkgs, ... }:
{
	home = {
		packages = with pkgs; [
			way-displays
			yq-go
		];

		file = {
			".config/way-displays/clamshell.sh" = {
				source = ./way-displays/clamshell.sh; 
				executable = true;
			};
			".config/way-displays/cfg.yaml".source = ./way-displays/cfg.yaml;
		};
	};

 	#  systemd.user.services = {
	# 	lid-switch-handler = {
	# 		Unit = {
	# 			Description = "Run clamshell script when the lid state changes";
	# 		};
	#     Install = {
	# 			WantedBy = [ "default.target" ];
	# 		};
	#     Service = {
	#       ExecStart = "${config.xdg.configHome}/way-displays/clamshell.sh";
	#       Restart = "on-failure";
	#     };
	#   };
	# };
	wayland.windowManager.sway.config.startup = lib.mkAfter [
		{
			command = "${pkgs.way-displays}/bin/way-displays > /tmp/way-displays.\${XDG_VTNR}.\${USER}.log 2>&1 &";
			always = false;
		}
		{
			command = "${config.xdg.configHome}/way-displays/clamshell.sh";
			always = true;		
		}
	];
}
