{ lib, pkgs, ... }:
{
	home = {
		packages = with pkgs; [
			way-displays
			yq-go
		];

		file = {
			".config/way-displays/cfg.yaml".source = ./cfg.yaml;
		};
	};

	wayland.windowManager.sway.config.startup = lib.mkAfter [
		{
			command = "${pkgs.way-displays}/bin/way-displays > /tmp/way-displays.\${XDG_VTNR}.\${USER}.log 2>&1 &";
			always = false;
		}
		{
			command = "./clamshell.sh";
			always = true;		
		}
	];
}
