{ pkgs, ... }:
{
	home.packages = with pkgs; [
			way-displays
	];

	services.way-displays = {
		enable = true;
		systemdTarget = "sway-session.target";
		settings = {
			SCALING = true;
			AUTO_SCALE = true;
			ARRANGE = "COLUMN";
			ALIGN = "MIDDLE";
			ORDER = [
				"DP-1"
				"eDP-1"
			];
			SCALE = [
				{
					NAME_DESC = "eDP-1";
					SCALE = 1.25;
				}
			];
		};
	};
}
