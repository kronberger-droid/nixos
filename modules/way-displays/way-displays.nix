{ config, lib, pkgs, ... }:
{
	home = {
		packages = with pkgs; [
			way-displays
			yq-go
		];

		file = {
			".config/way-displays/clamshell.sh" = {
				source = ./clamshell.sh; 
				executable = true;
			".config/way-displays/cfg.yaml".source = ./cfg.yaml;
		};
	};

	systemd.user.services.lid-switch-handler = {
	  Description = "Run a script when the lid state changes";
	  WantedBy = [ "default.target" ];
	  Service = {
	    ExecStart = "${config.xdg.configHome}/way-displays/clamshell.sh";
	    Restart = "always";
	    Environment = [
	      "WAYLAND_DISPLAY=wayland-0"
	      "XDG_RUNTIME_DIR=/run/user/%U"
	    ];
	  };
	};
	wayland.windowManager.sway.config.startup = lib.mkAfter [
		{
			command = "${pkgs.way-displays}/bin/way-displays > /tmp/way-displays.\${XDG_VTNR}.\${USER}.log 2>&1 &";
			always = false;
		}
		# {
		# 	command = "./clamshell.sh";
		# 	always = true;		
		# }
	];
}
