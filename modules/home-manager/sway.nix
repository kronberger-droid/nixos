{ config, pkgs, lib, host, isNotebook, ... }:
let
  palette         = config.myTheme.palette;
  backgroundColor = config.myTheme.backgroundColor;
  textColor       = config.myTheme.textColor;
  accentColor     = config.myTheme.accentColor;

  ws1 = "1 browser";
  ws2 = "2 writing";
  ws3 = "3 research";
  ws4 = "4 coding";
  ws5 = "5 studying";
  ws6 = "6 homework";
  ws7 = "7 work";
  ws8 = "8 nix";
  ws9 = "9 social";
  ws10 = "10 git";

  modKey = "Mod4";

  backgroundImage = ./sway/deathpaper.jpg;

  hostDispl = {
    intelNuc = {
      "HDMI-A-1" = {
        mode  = "2560x1440@143.912Hz";
        pos   = "0 0";
        scale = "1";
        bg = "${backgroundImage} fill";
      };
    };
    spectre = {
      "eDP-1" = {
        bg = "${backgroundImage} fill";
      };
    };
  };
in
{
  imports = [
    ./sway/swayidle.nix
    ./waybar.nix
    ./theme.nix
    ./rofi.nix
    ./sway/audio-idle-inhibit.nix
    ./sway/swaylock.nix
    ./sway/mako.nix
  ] ++ lib.optionals isNotebook [
    ./way-displays.nix
  ];

  home.packages = with pkgs; [
    swaylock
    swayidle
    swayimg
    wl-clipboard
    brightnessctl
    wlsunset
    grim
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
    lsof
    sway-scratch
    libinput
    woomer

    # xdg desktop portal
    xdg-user-dirs
    xdg-desktop-portal-wlr
    xdg-desktop-portal
    xdg-desktop-portal-gtk
  ];

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraConfig = builtins.readFile "${./sway/config}";
    extraSessionCommands = ''
      export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/keyring/ssh
    '';
    config = rec {
      modifier = modKey;
      terminal = "${pkgs.kitty}/bin/kitty";
      output = if builtins.hasAttr host hostDispl then hostDispl.${host} else {};
      assigns = {
        "${ws9}" = [
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
          command = "${pkgs.sway-contrib.inactive-windows-transparency}/bin/inactive-windows-transparency.py --opacity 0.95 --focused 1.0";
          always = false;
        }
        {
          command = "${pkgs.thunderbird}/bin/thunderbird";
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
          command = "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=ssh";
          always = false;
        }
      ];
      colors = {
        background = backgroundColor;

        focused = {
          border       = accentColor;
          background   = accentColor;
          text         = backgroundColor;
          indicator    = textColor;
          childBorder  = accentColor;
        };
        focusedInactive = {
          border      = palette.color1;
          background  = palette.color1;
          text        = palette.color5;
          indicator   = palette.color3;
          childBorder = palette.color1;
        };
        unfocused = {
          border      = palette.color1;
          background  = backgroundColor;
          text        = palette.color5;
          indicator   = textColor;
          childBorder = palette.color1;
        };
        urgent = {
          border      = palette.color8;
          background  = palette.color8;
          text        = backgroundColor;
          indicator   = palette.color9;
          childBorder = palette.color8;
        };
        placeholder = {
          border      = backgroundColor;
          background  = backgroundColor;
          text        = palette.color5;
          indicator   = backgroundColor;
          childBorder = backgroundColor;
        };
      };

      focus.mouseWarping = "container";

      menu = "${pkgs.rofi-wayland}/bin/rofi -show drun";

      defaultWorkspace = "workspace ${ws1}";

      keybindings = lib.mkOptionDefault {
        # brave
        "${modifier}+Shift+s" = "exec ${pkgs.brave}/bin/brave";
        # take a screenshot
        "${modifier}+Shift+a" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save area - | ${pkgs.swappy}/bin/swappy -f - $$ [[ $(${pkgs.wl-clipboard}/bin/wl-paste -l) == 'image/png' ]]";
        # reload sway
        "${modifier}+Shift+c" = "exec swaymsg reload";
        # open powermenu
        "${modifier}+Shift+e" = "exec ${config.xdg.configHome}/rofi/powermenu/powermenu.sh";
        # open local send app
        "${modifier}+Shift+z" = "exec ${pkgs.localsend}/bin/localsend_app";
        # open bitwarden
        "${modifier}+Shift+w" = "exec ${pkgs.bitwarden}/bin/bitwarden";
        # open floating btop shell
        "${modifier}+Shift+t" = "exec ${pkgs.kitty}/bin/kitty --app-id floating_shell -e ${pkgs.btop}/bin/btop";
        # zooming and highlighting for screen share
        "${modifier}+Shift+y" = "exec ${pkgs.woomer}/bin/woomer";
        # open file managers
        "${modifier}+Shift+x" = "exec ${pkgs.kitty}/bin/kitty --app-id floating_shell -e ${pkgs.yazi}/bin/yazi $(${config.xdg.configHome}/kitty/cwd.sh)";
        "${modifier}+Shift+n" = "exec ${pkgs.nemo-with-extensions}/bin/nemo $(${config.xdg.configHome}/kitty/cwd.sh)";
        # open terminals
        "${modifier}+Shift+Return" = "exec ${pkgs.kitty}/bin/kitty --app-id floating_shell --working-directory $(${config.xdg.configHome}/kitty/cwd.sh)";
        "${modifier}+Return" = "exec '${pkgs.kitty}/bin/kitty --working-directory $(${config.xdg.configHome}/kitty/cwd.sh)'";

        # Toggle waybar
        "${modifier}+Shift+b" = "exec ${config.xdg.configHome}/waybar/toggle-waybar.sh";

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
        inner = 4;
        outer = 2;
        smartGaps = true;
        smartBorders = "no_gaps";
      };
      input = {
        "*" = {
          xkb_options = "compose:menu";
          xkb_layout = "us";
          xkb_variant = ",";
        };
      } // (
        if host == "t480s" then {
          "1267:32:Elan_Touchpad" = {
            natural_scroll = "enabled";
            tap = "enabled";
          };
        } else if host == "spectre" then {
          "1739:52912:SYNA32BF:00_06CB:CEB0_Touchpad" = {
            natural_scroll = "enabled";
            tap = "enabled";
            pointer_accel = "0.3";
          };
        } else {}
      );
      bars = [];
    };
  };
}
