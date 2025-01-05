{ config, pkgs, lib, host, ... }:

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

  # Determine the output name based on the hostname
  outputName =
  if host == "intelNuc" then
    "HDMI-A-1"
  else if host == "t480s" then
    "eDP-1"
  else
    throw "Unknown hostname: ${host}";

  isNotebook = host == "t480s";
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
    brightnessctl
    mako
    wlsunset
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
    libnotify
    way-displays
    swaybg
  ];

  services.mako = {
    enable = true;
    defaultTimeout = 10000;
    borderRadius = 8;
    borderColor = accentColor;
    backgroundColor = backgroundColor + "CC";
  };

  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock;
    settings = {
      image = "/etc/nixos/configs/deathpaper.jpg";
      font-size = 24;
      indicator-idle-visible = false;
      inside-color = backgroundColor + "CC";
      indicator-radius = 80;
      ring-color = backgroundColor;
      key-hl-color = accentColor;
      show-failed-attempts = true;
    };
  };

  services.swayidle = {
    enable = true;
    systemdTarget = "graphical-session.target";
    timeouts = [
      {
        timeout = 295;
        command = "${pkgs.libnotify}/bin/notify-send 'Locking in 5 seconds' -t 5000";
      }
      {
        timeout = 300;
        command = "${pkgs.swaylock-effects}/bin/swaylock -f &";
      }
      {
        timeout = 360;
        command = "${pkgs.sway}/bin/swaymsg 'output * dpms off'";
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
      }
    ];
    events = [
      {
        event = "before-sleep";
        command = "${pkgs.swaylock-effects}/bin/swaylock -f &";
      }
    ];
  };
  
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraConfigEarly = ''
      exec_always {
        --no-startup-id sleep 30 && ${pkgs.megasync} &
        --no-startup-id sleep 33 && ${pkgs.megasync} &        
        ${pkgs.sway-contrib.inactive-windows-transparency}/bin/inactive-windows-transparency.py --opacity 0.8 --focused 1.0
        ${pkgs.swaybg}/bin/swaybg -i /etc/nixos/configs/deathpaper.jpg -m fill
        ${pkgs.autotiling}/bin/autotiling
        ${pkgs.wlsunset}/bin/wlsunset -l 48.2 -L 16.4
      }
    '';

    extraConfig = ''
      for_window [app_id = "floating_file_shell"] floating enable, sticky enable, resize set 1600 1000
      for_window [app_id = "nemo"] floating enable, sticky enable, resize set 900 700
      for_window [app_id = "floating_shell"] floating enable, border pixel 1, sticky enable, resize set 900 700
      for_window [instance = "megasync"] floating enable, sticky enable, border pixel 0, move position cursor, move down 35
      for_window [app_id = "localsend_app"] floating enable, sticky enable, resize set 1200 800
      for_window [instance = "bitwarden"] floating enable, sticky enable, resize set 1200 800
      for_window [app_id = "org.speedcrunch"] floating enable, sticky enable, resize set 1200 800
      
      bindgesture swipe:3:right workspace next
      bindgesture swipe:3:left workspace prev
    '';

    config = rec {
      modifier = "Mod4"; # Super key
      terminal = "kitty";

      startup = lib.optional isNotebook {
        command = "way-displays > /tmp/way-displays.\${XDG_VTNR}.\${USER}.log 2>&1 &";
      };
      
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

      focus.mouseWarping = "container";
      window = {
        titlebar = false;
      };
      
      menu = "rofi -show drun -theme /etc/nixos/configs/rofi/launcher/style-2.rasi";

      defaultWorkspace = "workspace ${ws1}";
      
      keybindings = lib.mkOptionDefault {
        "${modifier}+Shift+x" = "exec ${pkgs.nemo}/bin/nemo";
        "${modifier}+Shift+s" = "exec ${pkgs.brave}/bin/brave";
        "${modifier}+Shift+a" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save area - | ${pkgs.swappy}/bin/swappy -f - $$ [[ $(${pkgs.wl-clipboard}/bin/wl-paste -l) == 'image/png' ]]";
        "${modifier}+Shift+c" = "exec swaymsg reload";
        "${modifier}+Shift+e" = "exec /etc/nixos/configs/rofi/powermenu/powermenu.sh";
        "${modifier}+Shift+z" = "exec ${pkgs.localsend}/bin/localsend_app";
        "${modifier}+Shift+w" = "exec ${pkgs.bitwarden}/bin/bitwarden";
        "${modifier}+Return" = "exec bash -c 'kitty --working-directory $(/etc/nixos/scripts/cwd.sh)'";
        
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
        "${modifier}+Shift+1" = "move container to workspace ${ws1}; workspace ${ws1}";
        "${modifier}+Shift+2" = "move container to workspace ${ws2}; workspace ${ws2}";
        "${modifier}+Shift+3" = "move container to workspace ${ws3}; workspace ${ws3}";
        "${modifier}+Shift+4" = "move container to workspace ${ws4}; workspace ${ws4}";
        "${modifier}+Shift+5" = "move container to workspace ${ws5}; workspace ${ws5}";
        "${modifier}+Shift+6" = "move container to workspace ${ws6}; workspace ${ws6}";
        "${modifier}+Shift+7" = "move container to workspace ${ws7}; workspace ${ws7}";
        "${modifier}+Shift+8" = "move container to workspace ${ws8}; workspace ${ws8}";
        "${modifier}+Shift+9" = "move container to workspace ${ws9}; workspace ${ws9}";
        "${modifier}+Shift+0" = "move container to workspace ${ws10}; workspace ${ws10}";
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
