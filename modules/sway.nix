{ config, pkgs, lib, ... }:

let
  color0 = "#1e1e1e";
  color1 = "#2c2f33";
  color2 = "#373c45";
  color3 = "#555555";
  color4 = "#6c7a89";
  color5 = "#c0c5ce";
  color6 = "#dfe1e8";
  color7 = "#eff0f1";
  color8 = "#423c38";
  color9 = "#6e665f";
  color10 = "#786048";
  color11 = "#988a71";
  color12 = "#8a8177";
  color13 = "#9c9287";
  color14 = "#a39e93";
  color15 = "#b6b1a9";

  backgroundColor = color0;
  textColor = color6;
  selectionColor = color1;
  accentColor = color12;

  ws1 = "1 work";
  ws2 = "2 research";
  ws3 = "3 coding";
  ws4 = "4 browser";
  ws5 = "5 terminal";
  ws6 = "6 nix";
  ws7 = "7 pending";
  ws8 = "8 studying";
  ws9 = "9 social";
  ws10 = "10 git";
in
{
  imports = [
    ./waybar.nix
  ];

  home.packages = with pkgs; [
    # for sway
    swaylock
    swayidle
    wl-clipboard
    mako
    grim
    rofi
    slurp
    pulsemixer
    autotiling
    swappy
    sway-contrib.grimshot
    sway-contrib.inactive-windows-transparency
    swaycwd
    jq
    gron
  ];

  services.mako = {
    enable = true;
    defaultTimeout = 10000;
    borderRadius = 8;
    borderColor = accentColor;
    backgroundColor = backgroundColor + "CC";
  };
  
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;

    extraConfigEarly = ''
      exec_always {
        ${pkgs.sway-contrib.inactive-windows-transparency}/bin/inactive-windows-transparency.py --opacity 0.8 --focused 1.0;
        swaymsg 'output HDMI-A-1 bg /etc/nixos/configs/sway/deathpaper.jpg fill'
        autotiling
      }
    '';

    extraConfig = ''
      exec_always {
        ${pkgs.megasync}/bin/megasync &
      }
      for_window [app_id = "floating_file_shell"] floating enable, sticky enable, resize set 1600 1000
      for_window [app_id = "org.gnome.Nautilus"] floating enable, sticky enable, resize set 1200 800
      for_window [app_id = "floating_shell"] floating enable, border pixel 1, sticky enable, resize set 900 700
      for_window [instance = "megasync"] floating enable, sticky enable, move position cursor, move down 35
      for_window [app_id = "localsend_app"] floating enable, sticky enable, resize set 1200 800
      for_window [instance = "bitwarden"] floating enable, sticky enable, resize set 1200 800
      for_window [app_id = "org.speedcrunch"] floating enable, sticky enable, resize set 1200 800
    '';

    config = rec {
      modifier = "Mod4"; # Super key
      terminal = "kitty";

      colors = {
        background = backgroundColor;

        focused = {
          border = accentColor;
          background = accentColor;
          text = backgroundColor;
          indicator = textColor;
          childBorder = accentColor;
        };
        focusedInactive = {
          border = color1;
          background = color1;
          text = color5;
          indicator = color3;
          childBorder = color1;
        };
        unfocused = {
          border = color1;
          background = backgroundColor;
          text = color5;
          indicator = textColor;
          childBorder = color1;
        };
        urgent = {
          border = color8;
          background = color8;
          text = backgroundColor;
          indicator = color9;
          childBorder = color8;
        };
        placeholder = {
          border = backgroundColor;
          background = backgroundColor;
          text = color5;
          indicator = backgroundColor;
          childBorder = backgroundColor;
        };
      };

      window = {
        titlebar = false;
      };

      menu = "rofi -show drun -theme /etc/nixos/configs/rofi/launcher/style-2.rasi";

      startup = [
        { command = "swaymsg output HDMI-A-1 bg /etc/nixos/configs/sway/deathpaper.jpg fill"; }
      ];

      defaultWorkspace = "workspace ${ws1}";
      
      keybindings = lib.mkOptionDefault {
        # "Mod4+Shift+x" = "exec ${pkgs.kitty}/bin/kitty --app-id floating_file_shell -e ${pkgs.yazi}/bin/yazi";
        "${modifier}+Shift+x" = "exec nautilus";
        "${modifier}+Shift+s" = "exec ${pkgs.brave}/bin/brave";
        "${modifier}+Shift+a" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save area - | ${pkgs.swappy}/bin/swappy -f - $$ [[ $(${pkgs.wl-clipboard}/bin/wl-paste -l) == 'image/png' ]]";
        "${modifier}+Shift+c" = "exec swaymsg reload";
        "${modifier}+Shift+e" = "exec /etc/nixos/configs/rofi/powermenu/powermenu.sh";
        "${modifier}+Shift+z" = "exec ${pkgs.localsend}/bin/localsend_app";
        "${modifier}+Shift+w" = "exec ${pkgs.bitwarden}/bin/bitwarden";
        
        # Workspace switching
        "${modifier}+1" = "workspace ${ws1}";
        "${modifier}+2" = "workspace ${ws2}";
        "${modifier}+3" = "workspace ${ws3}";
        "${modifier}+4" = "workspace ${ws4}";
        "${modifier}+5" = "workspace ${ws5}";
        "${modifier}+6" = "workspace ${ws6}";
        "${modifier}+7" = "workspace ${ws7}";
        "${modifier}+8" = "workspace ${ws8}";
        "${modifier}+9" = "workspace ${ws9}";
        "${modifier}+0" = "workspace ${ws10}";

        # Move container to workspace
        "${modifier}+Shift+1" = "move container to workspace ${ws1}";
        "${modifier}+Shift+2" = "move container to workspace ${ws2}";
        "${modifier}+Shift+3" = "move container to workspace ${ws3}";
        "${modifier}+Shift+4" = "move container to workspace ${ws4}";
        "${modifier}+Shift+5" = "move container to workspace ${ws5}";
        "${modifier}+Shift+6" = "move container to workspace ${ws6}";
        "${modifier}+Shift+7" = "move container to workspace ${ws7}";
        "${modifier}+Shift+8" = "move container to workspace ${ws8}";
        "${modifier}+Shift+9" = "move container to workspace ${ws9}";
        "${modifier}+Shift+0" = "move container to workspace ${ws10}";
      };
      
      gaps = {
        inner = 8;
        outer = 4;
      };

      input = {
        "*" = {
          xkb_options = "grp:lalt_lshift_toggle,caps:escape";
          xkb_layout = "us,at";
          xkb_variant = ",";
        };
      };

      bars = [];
    };
  };
}
