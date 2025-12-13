{
  pkgs,
  host,
  ...
}: {
  # Kanshi - Automatic display configuration for Wayland
  # Profile-based approach with predictable behavior

  services.kanshi = {
    enable = host != "intelNuc"; # Disable for Intel NUC - single static display
    systemdTarget = "graphical-session.target";

    settings =
      if host == "intelNuc"
      then [
        {
          profile.name = "desktop";
          profile.outputs = [
            {
              criteria = "HDMI-A-1";
              mode = "2560x1440@119.998Hz";
              position = "0,0";
              scale = 1.0;
              adaptiveSync = true;
            }
          ];
        }
      ]
      else if host == "t480s"
      then [
        # Laptop only profile
        {
          profile.name = "laptop";
          profile.outputs = [
            {
              criteria = "eDP-1";
              mode = "1920x1080";
              position = "0,0";
              scale = 1.0;
            }
          ];
        }
        # Docked profile with external display
        {
          profile.name = "docked";
          profile.outputs = [
            {
              criteria = "eDP-1";
              mode = "1920x1080";
              position = "0,0";
              scale = 1.0;
            }
            {
              criteria = "DP-*";
              mode = "2560x1440";
              position = "1920,0";
            }
          ];
        }
      ]
      else if host == "spectre"
      then [
        # Standard laptop profile
        {
          profile.name = "laptop";
          profile.outputs = [
            {
              criteria = "eDP-1";
              position = "0,0";
              scale = 1.25;
            }
          ];
        }

        {
          profile.name = "uni-desk-aoc";
          profile.outputs = [
            {
              criteria = "AOC U3277WB 0x0000061F";
              position = "0,0";
              scale = 1.5;
            }
          ];
        }
        # University desk with Iiyama monitor
        {
          profile.name = "uni-desk";
          profile.outputs = [
            {
              criteria = "eDP-1";
              position = "0,1080";
              scale = 1.25;
            }
            {
              criteria = "Iiyama North America PL2475HD 11098M2205863";
              position = "0,0";
              scale = 1.0;
            }
          ];
        }
      ]
      else [
        # Fallback for portable or other hosts
        {
          profile.name = "default";
          profile.outputs = [
            {
              criteria = "*";
            }
          ];
        }
      ];
  };

  home.packages = with pkgs; [
    kanshi
  ];
}
