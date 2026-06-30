{
  pkgs,
  host,
  ...
}: {
  # Shikane - Dynamic display configuration for Wayland (kanshi successor)
  # Profile-based, with richer per-attribute output matching.
  #
  # search syntax: "[[attrs]kind]pattern"
  #   attrs ∈ {d=description, n=name, m=model, v=vendor, s=serialnumber}
  #   kind  ∈ {= exact, % substring, / regex}   (defaults to exact, any attr)
  # Verify the real attribute strings with `niri msg outputs`.

  services.shikane = {
    enable = host != "intelNuc"; # Disable for Intel NUC - single static display

    settings.profile =
      if host == "t480s"
      then [
        # Laptop only profile
        {
          name = "laptop";
          output = [
            {
              search = "n=eDP-1";
              enable = true;
              mode = "1920x1080";
              position = "0,0";
              scale = 1.0;
            }
          ];
        }
        # Docked profile with external display
        {
          name = "docked";
          output = [
            {
              search = "n=eDP-1";
              enable = true;
              mode = "1920x1080";
              position = "0,0";
              scale = 1.0;
            }
            {
              search = "n/DP-.*";
              enable = true;
              mode = "2560x1440";
              position = "1920,0";
            }
          ];
        }
        # Presentation mode - mirror to external display
        {
          name = "presentation";
          output = [
            {
              search = "n=eDP-1";
              enable = true;
              mode = "1920x1080";
              position = "0,0";
              scale = 1.0;
            }
            {
              search = "n/DP-.*";
              enable = true;
              mode = "1920x1080";
              position = "0,0";
            }
          ];
        }
      ]
      else if host == "spectre"
      then [
        # Standard laptop profile
        {
          name = "laptop";
          output = [
            {
              search = "n=eDP-1";
              enable = true;
              position = "0,0";
              scale = 1.25;
            }
          ];
        }
        {
          name = "uni-desk-aoc-dual";
          output = [
            {
              search = "m=U3277WB";
              enable = true;
              position = "0,0";
              scale = 1.5;
            }
            {
              search = "n=eDP-1";
              enable = true;
              position = "640,1440";
              scale = 1.5;
            }
          ];
        }
        {
          name = "uni-desk-aoc-only";
          output = [
            {
              search = "n=eDP-1";
              enable = false;
            }
            {
              search = "m=U3277WB";
              enable = true;
              position = "0,0";
              scale = 2.0;
            }
          ];
        }
        {
          name = "uni-desk-aoc";
          output = [
            {
              search = "m=U3277WB";
              enable = true;
              position = "0,0";
              scale = 2.0;
            }
          ];
        }
        # University desk with Iiyama monitor
        {
          name = "uni-desk";
          output = [
            {
              search = "n=eDP-1";
              enable = true;
              position = "0,1080";
              scale = 1.25;
            }
            {
              search = "m=PL2475HD";
              enable = true;
              position = "0,0";
              scale = 1.0;
            }
          ];
        }
      ]
      else [
        # Fallback for portable or other hosts
        {
          name = "default";
          output = [
            {
              search = "n/.*";
              enable = true;
            }
          ];
        }
      ];
  };
}
