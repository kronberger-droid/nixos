{ pkgs, lib, host, ... }:

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

  powermenu = "${../configs/rofi/powermenu}";

  
  # Define paths for colors and fonts
  # colorsPath = "${toString powermenu}/shared/colors.rasi";
  # fontsPath = "${toString powermenu}/shared/fonts.rasi";

  # # Function to process theme files
  # processTheme = path: builtins.replaceStrings 
  #   [ "COLORS_PATH" "FONTS_PATH" ]
  #   [ colorsPath fontsPath ]
  #   (builtins.readFile path);
  #  # Process all theme files

  # themeFiles = {
  #   "style-1.rasi" = processTheme "${powermenu}/style-1.rasi";
  #   "style-2.rasi" = processTheme "${powermenu}/style-2.rasi";
  # };
in
{
  imports = [
    ./waybar.nix
  ];

  home.packages = with pkgs; [
    # for sway
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
    sway-scratch
  ] ++ lib.optionals isNotebook [
    way-displays
  ];

  services = {
    gnome-keyring.enable = true;
    mako = {
      enable = true;
      defaultTimeout = 10000;
      borderRadius = 8;
      borderColor = accentColor;
      backgroundColor = backgroundColor + "CC";
    };
  };

  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock;
    settings = {
      image = "${../configs/deathpaper.jpg}";
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
    extraConfig = builtins.readFile "${../configs/sway/config}";
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
        criteria = [
          { app_id = "nemo"; }
        ];
      };
      startup = [
        {
          command = "${pkgs.megasync}/bin/megasync $$ ${pkgs.megasync}/bin/megasync";
          always = false;
        }
        {
          command = "${pkgs.sway-contrib.inactive-windows-transparency}/bin/inactive-windows-transparency.py --opacity 0.85 --focused 1.0";
          always = false;
        }
        {
          command = "${pkgs.swaybg}/bin/swaybg -i /etc/nixos/configs/deathpaper.jpg -m fill";
          always = false;
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
          command = "exec ${../scripts/once.sh} ${pkgs.sway-audio-idle-inhibit}/bin/sway-audio-idle-inhibit";
          always = true;
        }
      ] ++ lib.optionals isNotebook [
        {
          command = "${pkgs.way-displays}/bin/way-displays > /tmp/way-displays.\${XDG_VTNR}.\${USER}.log 2>&1 &";
          always = false;
        }
        {
          command = "${../scripts}/clamshell.sh";
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

      menu = "rofi -show drun -theme /etc/nixos/configs/rofi/launcher/style-2.rasi";

      defaultWorkspace = "workspace ${ws1}";

      keybindings = lib.mkOptionDefault {
        "${modifier}+Shift+x" = "exec ${pkgs.nemo-with-extensions}/bin/nemo";
        "${modifier}+Shift+s" = "exec ${pkgs.brave}/bin/brave";
        "${modifier}+Shift+a" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save area - | ${pkgs.swappy}/bin/swappy -f - $$ [[ $(${pkgs.wl-clipboard}/bin/wl-paste -l) == 'image/png' ]]";
        "${modifier}+Shift+c" = "exec swaymsg reload";
        "${modifier}+Shift+e" = "exec ${powermenu}/powermenu.sh";
        "${modifier}+Shift+z" = "exec ${pkgs.localsend}/bin/localsend_app";
        "${modifier}+Shift+w" = "exec ${pkgs.bitwarden}/bin/bitwarden";
        "${modifier}+Return" = "exec 'kitty --working-directory $(/etc/nixos/scripts/cwd.sh)'";

        # Brightness control
        "XF86MonBrightnessDown" = "exec ${pkgs.light}/bin/light -U 10";
        "XF86MonBrightnessUp" = "exec ${pkgs.light}/bin/light -A 10";

        # Volume control using pulsemixer
        "XF86AudioRaiseVolume" = "exec ${pkgs.pulsemixer}/bin/pulsemixer --change-volume +1";
        "XF86AudioLowerVolume" = "exec ${pkgs.pulsemixer}/bin/pulsemixer --change-volume -1";
        "XF86AudioMute" = "exec ${pkgs.pulsemixer}/bin/pulsemixer --toggle-mute";

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
      };
      gaps = {
        inner = 8;
        outer = 4;
      };
      input = {
        "*" = {
          xkb_options = "grp:lalt_lshift_toggle";
          xkb_layout = "us,at";
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
