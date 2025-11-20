{ pkgs, host, ... }:

{
  # Kanshi - Automatic display configuration for Wayland
  # Profile-based approach with predictable behavior

  services.kanshi = {
    enable = true;
    systemdTarget = "sway-session.target";

    settings =
      if host == "intelNuc" then [
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
      else if host == "t480s" then [
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
      else if host == "spectre" then [
        # Laptop only profile
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
        # Docked profile with external display
        {
          profile.name = "docked";
          profile.outputs = [
            {
              criteria = "eDP-1";
              position = "0,0";
              scale = 1.25;
            }
            {
              criteria = "DP-*|HDMI-*";
              position = "1536,0"; # Adjusted for 1.25 scale (1920/1.25)
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
