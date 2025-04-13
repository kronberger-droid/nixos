{ lib, pkgs, host, ... }:
let
	cfgFile = {
		"t480s" = ./way-displays/cfg_t480s.yaml;
		"spectre" = ./way-displays/cfg_spectre.yaml;
	}.${host};
in
{
	home = {
		packages = with pkgs; [
			way-displays
		];
		
		file.".config/way-displays/cfg.yaml".source = cfgFile;
	};
	wayland.windowManager.sway = {
		extraConfigEarly = lib.mkAfter ''
			bindswitch --locked lid:on exec ${pkgs.way-displays}/bin/way-displays -s DISABLED "eDP-1"
			bindswitch --locked lid:off exec ${pkgs.way-displays}/bin/way-displays -d DISABLED "eDP-1"
		'';
		config.startup = lib.mkAfter [
			{
				command = "${pkgs.way-displays}/bin/way-displays > /tmp/way-displays.\${XDG_VTNR}.\${USER}.log 2>&1 &";
				always = false;
			}
		];
	};
}
