{ lib, pkgs, ... }:
{
	home.packages = with pkgs; [
			way-displays
	];
		
	services.way-displays = {
		enable = true;
		settings = {
			SCALING = true;
			AUTO_SCALE = true;
			SCALE = [
				{
					NAME_DESC = "eDP-1";
					SCALE = 1.25;
				}
			];
		};
	};

	wayland.windowManager.sway = {
		extraConfigEarly = lib.mkAfter ''
			bindswitch --locked lid:on exec ${pkgs.way-displays}/bin/way-displays -s DISABLED "eDP-1"
			bindswitch --locked lid:off exec ${pkgs.way-displays}/bin/way-displays -d DISABLED "eDP-1"
		'';
	};
}
