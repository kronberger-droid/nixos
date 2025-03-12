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

  ws1 = "1 browser";
  ws2 = "2 writing";
  ws3 = "3 research";
  ws4 = "4 coding";
  ws5 = "5 studying";
  ws6 = "6 work";
  ws7 = "7 pending";
  ws8 = "8 nix";
  ws9 = "9 social";
  ws10 = "10 git";

  isNotebook = host == "t480s";
in
{
  imports = [
    ./waybar.nix
    ./theme.nix
    ./rofi.nix
  ] ++ lib.optionals isNotebook [
    ./way-displays.nix
  ];

  xdg.configFile."sway/once.sh".source = ./sway/once.sh;
  
  home.packages = with pkgs; [
    swaylock
    swayidle
    sway-audio-idle-inhibit
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
    swaybg
    swayimg
    lsof
    sway-scratch
  ];

  services = {
    mako = {
      enable = true;
      defaultTimeout = 10000;
      borderRadius = 8;
      borderColor = accentColor;
      backgroundColor = backgroundColor + "CC";
    };
    poweralertd.enable = true;
  };

  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock;
    settings = {
      image = "${./sway/deathpaper.jpg}";
      font-size = 24;
      indicator-idle-visible = false;
      inside-color = backgroundColor + "CC";
      indicator-radius = 80;
      ring-color = backgroundColor;
      key-hl-color = accentColor;
      show-failed-attempts = true;
      ignore-empty-password = true;
    };
  };

  services.swayidle = {
    enable = true;
    systemdTarget = "graphical-session.target";
    timeouts = [
      {
        timeout = 395;
        command = "${pkgs.libnotify}/bin/notify-send 'Locking in 5 seconds' -t 5000";
      }
      {
        timeout = 400;
        command = "${pkgs.swaylock-effects}/bin/swaylock -f &";
      }
      {
        timeout = 460;
        command = "${pkgs.sway}/bin/swaymsg 'output * dpms off'";
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
      }
      {
        timeout = 560;
        command = "${pkgs.systemd}/bin/systemctl suspend";
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
    extraConfig = builtins.readFile "${./sway/config}";
    config = rec {
      modifier = "Mod4"; # Super key
      terminal = "${pkgs.kitty}/bin/kitty";
      assigns = {
        "${ws9}" = [
          { title = "WhatsApp Web"; }
          { app_id = "thunderbird"; }
          { class = "Spotify"; }
        ];
        "${ws10}" = [
          { class = "GitHub Desktop"; }
        ];
      };
      window = {
        titlebar = false;
      };
      floating = {
        border = 0;
        criteria = [
          { app_id = "nemo"; }
        ];
      };
      startup = [
        {
          command = "${pkgs.sway-contrib.inactive-windows-transparency}/bin/inactive-windows-transparency.py --opacity 0.9 --focused 1.0";
          always = false;
        }
        {
          command = "${config.xdg.configHome}/sway/once.sh ${pkgs.swaybg}/bin/swaybg -i ${./sway/deathpaper.jpg} -m fill -o '*'";
          always = true;
        }
        {
          command = "${pkgs.autotiling}/bin/autotiling";
          always = false;
        }
        {
          command = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
          always = false;
        }
        {
          command = "${pkgs.wlsunset}/bin/wlsunset -l 48.2 -L 16.4";
          always = false;
        }
        {
          command = "${config.xdg.configHome}/sway/once.sh ${pkgs.sway-audio-idle-inhibit}/bin/sway-audio-idle-inhibit";
          always = true;
        }
      ];
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

      menu = "rofi -show drun";

      defaultWorkspace = "workspace ${ws1}";

      keybindings = lib.mkOptionDefault {
        "${modifier}+Shift+x" = "exec ${pkgs.nemo-with-extensions}/bin/nemo $(${config.xdg.configHome}/kitty/cwd.sh)";
        "${modifier}+Shift+s" = "exec ${pkgs.brave}/bin/brave";
        "${modifier}+Shift+a" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save area - | ${pkgs.swappy}/bin/swappy -f - $$ [[ $(${pkgs.wl-clipboard}/bin/wl-paste -l) == 'image/png' ]]";
        "${modifier}+Shift+c" = "exec swaymsg reload";
        "${modifier}+Shift+e" = "exec ${config.xdg.configHome}/rofi/powermenu/powermenu.sh";
        "${modifier}+Shift+z" = "exec ${pkgs.localsend}/bin/localsend_app";
        "${modifier}+Shift+w" = "exec ${pkgs.bitwarden}/bin/bitwarden";
        "${modifier}+Shift+t" = "exec ${pkgs.kitty}/bin/kitty --app-id floating_shell -e ${pkgs.btop}/bin/btop";

        "${modifier}+Shift+Return" = "exec ${pkgs.kitty}/bin/kitty --app-id floating_shell --working-directory $(${config.xdg.configHome}/kitty/cwd.sh)";
        "${modifier}+Return" = "exec '${pkgs.kitty}/bin/kitty --working-directory $(${config.xdg.configHome}/kitty/cwd.sh)'";

        # Brightness control
        "XF86MonBrightnessDown" = "exec ${pkgs.light}/bin/light -U 10";
        "XF86MonBrightnessUp" = "exec ${pkgs.light}/bin/light -A 10";

        # Volume control using pulsemixer
        "XF86AudioRaiseVolume" = "exec ${pkgs.pulsemixer}/bin/pulsemixer --change-volume +1";
        "XF86AudioLowerVolume" = "exec ${pkgs.pulsemixer}/bin/pulsemixer --change-volume -1";
        "XF86AudioMute" = "exec ${pkgs.pulsemixer}/bin/pulsemixer --toggle-mute";

        # Music control using waybar-mpris
        "XF86AudioNext" = "exec ${pkgs.waybar-mpris}/bin/waybar-mpris --send next";
        "XF86AudioPrev" = "exec ${pkgs.waybar-mpris}/bin/waybar-mpris --send prev";
        "XF86AudioPlay" = "exec ${pkgs.waybar-mpris}/bin/waybar-mpris --send toggle";

        # Size of scratchpad
        "${modifier}+minus" = "scratchpad show, resize set 1600 900";
        
        # Scaling using way-displays

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

        # Workspace Cycling
        "Mod1+l" = "workspace next";
        "Mod1+Right" = "workspace next";
        "Mod1+h" = "workspace prev";
        "Mod1+Left" = "workspace prev";

        "Mod1+Shift+h" = "move workspace output left";
        "Mod1+Shift+l" = "move workspace output right";
        "Mod1+Shift+k" = "move workspace output up";
        "Mod1+Shift+j" = "move workspace output down";
      };
      gaps = {
        inner = 6;
        outer = 3;
      };
      input = {
        "*" = {
          xkb_options = "compose:menu";
          xkb_layout = "us";
          xkb_variant = ",";
        };
        "1267:32:Elan_Touchpad" = {
          natural_scroll = "enabled";
          tap = "enabled";
        };
      };
      bars = [];
    };
  };
}
