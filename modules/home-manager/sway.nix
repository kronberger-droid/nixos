{
  config,
  pkgs,
  lib,
  host,
  isNotebook,
  ...
}: let
  ws1 = "1 browser";
  ws2 = "2 emulation";
  ws3 = "3 coding";
  ws4 = "4 research";
  ws5 = "5 writing";
  ws6 = "6 studying";
  ws7 = "7 work";
  ws8 = "8 messages";
  ws9 = "9 music";
  ws10 = "10 nixos";

  modKey = "Mod4";

  backgroundImage = ./sway/deathpaper.jpg;

  defaultBrowser = "${pkgs.firefox}/bin/firefox";
in {
  imports = [
    ./sway/swayidle.nix
    ./waybar.nix
    ./theme.nix
    ./rofi.nix
    ./sway/audio-idle-inhibit.nix
    ./sway/swaylock.nix
    ./sway/mako.nix
    ./kanshi.nix
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
    wiremix
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
    rot8

    xdg-user-dirs
  ];

  xdg.configFile."rot8/rot8.toml" = lib.mkIf (host == "spectre" || host == "portable") {
    text = ''
      # rot8 configuration for HP Spectre x360
      # Auto-rotation daemon for Sway

      # Touchscreen device to rotate
      [[touch-device]]
      name = "ELAN2513:00 04F3:2E2D"

      # Tablet/stylus device to rotate
      [[tablet-device]]
      name = "ELAN2513:00 04F3:2E2D Stylus"

      # Display to rotate
      [[display]]
      name = "eDP-1"

      # Threshold for rotation (degrees from horizontal)
      # Lower values make rotation more sensitive
      threshold = 0.5

      # Polling interval in milliseconds
      # How often to check the accelerometer
      poll-interval = 500

      # Allow all orientations (normal, left, right, inverted)
      # Set to false to disable upside-down rotation
      invert-mode = true
    '';
  };

  wayland.windowManager.sway = {
    enable = true;
    systemd.enable = true;
    wrapperFeatures.gtk = true;
    extraConfig =
      ''
        # Limit default floating window size
        floating_maximum_size ${if isNotebook then "1000 x 650" else "1200 x 800"}

        # Window rules with sizing
        for_window [app_id="nemo"] floating enable, sticky enable, resize set 1200 800
        for_window [app_id="floating_shell"] floating enable, border pixel 1, sticky enable, resize set 50ppt 60ppt
        for_window [app_id="localsend_app"] floating enable, sticky enable, resize set 1200 800
        for_window [app_id="Bitwarden"] floating enable, sticky enable, resize set 1200 800
        for_window [app_id="org.speedcrunch"] floating enable, sticky enable, resize set 800 600
        for_window [instance="gpartedbin"] floating enable
        for_window [title="Authentication Required"] floating enable

        # File dialogs with sizing
        for_window [title="(?:Open|Save) (?:File|Folder|As)"] floating enable, resize set 60 ppt 55 ppt
        for_window [title="(?:open|save) (?:file|folder|as)"] floating enable, resize set 60 ppt 55 ppt

        # Generic dialog types
        for_window [window_role="bubble"] floating enable
        for_window [window_role="task_dialog"] floating enable
        for_window [window_role="Preferences"] floating enable
        for_window [window_type="dialog"] floating enable
        for_window [window_type="menu"] floating enable
      ''
      + (
        if isNotebook
        then ''
          # Touchpad gestures for notebooks
          bindgesture swipe:3:right workspace next
          bindgesture swipe:3:left workspace prev

          # Lid switch handling - disable/enable internal display
          # logind handles suspend based on docking state
          # Note: lid:on means lid is closed, lid:off means lid is open
          bindswitch --reload --locked lid:on output eDP-1 disable
          bindswitch --reload --locked lid:off output eDP-1 enable
        ''
        else ""
      );
    config = rec {
      modifier = modKey;
      terminal = config.terminal.bin;
      output =
        {
          "*" = {
            bg = "${backgroundImage} fill";
          };
        }
        // (
          if host == "spectre"
          then {
            "eDP-1" = {
              scale = "1.25";
            };
          }
          else {}
        );
      window = {
        titlebar = false;
        border = 1;
      };
      floating = {
        border = 0;
        criteria = [
          {app_id = "nemo";}
          {app_id = "floating_shell";}
          {app_id = "pavucontrol";}
          {app_id = "nm-connection-editor";}
          {app_id = "blueman-manager";}
          {app_id = "imv";}
          {app_id = "mpv";}
          {title = "^Open File$";}
          {title = "^Save File$";}
          {title = "^Open Folder$";}
          {title = "^File Upload";}
          {title = "^Picture-in-Picture$";}
          {window_role = "pop-up";}
          {window_role = "dialog";}
          {window_type = "dialog";}
        ];
      };
      startup =
        [
          {
            command = "${pkgs.sway-contrib.inactive-windows-transparency}/bin/inactive-windows-transparency.py --opacity 0.95 --focused 1.0";
            always = false;
          }
          {
            command = "${pkgs.systemd}/bin/systemctl --user import-environment";
            always = false;
          }
          {
            command = "${pkgs.autotiling}/bin/autotiling";
            always = false;
          }
          {
            command = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
            always = false;
          }
          {
            command = "${pkgs.wlsunset}/bin/wlsunset -l 48.2 -L 16.4";
            always = false;
          }
        ]
        ++ (
          if host == "spectre" || host == "portable"
          then [
            {
              # Start rot8 only if rotation is not disabled (state file doesn't exist)
              command = "${pkgs.bash}/bin/bash -c 'if [ ! -f $HOME/.cache/rotation-state ]; then ${pkgs.rot8}/bin/rot8; fi'";
              always = false;
            }
          ]
          else []
        );
      # Base16 colors with custom brown accent for focused windows
      colors = {
        background = "#${config.scheme.base00}";

        # Focused window border: custom brown accent, text: base05
        focused = {
          border = "#${config.scheme.base0F}"; # Brown accent - matches background
          background = "#${config.scheme.base00}"; # Brown accent
          text = "#${config.scheme.base05}";
          indicator = "#${config.scheme.base0F}";
          childBorder = "#${config.scheme.base0F}"; # Brown accent
        };
        # Unfocused window border in group: border matches background
        focusedInactive = {
          border = "#${config.scheme.base00}";
          background = "#${config.scheme.base00}";
          text = "#${config.scheme.base05}";
          indicator = "#${config.scheme.base00}";
          childBorder = "#${config.scheme.base00}";
        };
        # Unfocused window border: border matches background
        unfocused = {
          border = "#${config.scheme.base00}";
          background = "#${config.scheme.base00}";
          text = "#${config.scheme.base05}";
          indicator = "#${config.scheme.base00}";
          childBorder = "#${config.scheme.base00}";
        };
        # Urgent window border: base08, text: base05
        urgent = {
          border = "#${config.scheme.base08}";
          background = "#${config.scheme.base08}";
          text = "#${config.scheme.base00}";
          indicator = "#${config.scheme.base08}";
          childBorder = "#${config.scheme.base08}";
        };
        placeholder = {
          border = "#${config.scheme.base00}";
          background = "#${config.scheme.base00}";
          text = "#${config.scheme.base05}";
          indicator = "#${config.scheme.base00}";
          childBorder = "#${config.scheme.base00}";
        };
      };

      focus.mouseWarping = "container";

      menu = "${pkgs.rofi}/bin/rofi -show drun";

      defaultWorkspace = "workspace ${ws1}";

      keybindings = lib.mkOptionDefault {
        # browser
        "${modifier}+Shift+s" = "exec ${defaultBrowser}";
        # dismiss notifications
        "${modifier}+Shift+d" = "exec ${pkgs.mako}/bin/makoctl dismiss -a";
        # take a screenshot
        "${modifier}+Shift+a" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save area - | ${pkgs.swappy}/bin/swappy -f - $$ [[ $(${pkgs.wl-clipboard}/bin/wl-paste -l) == 'image/png' ]]";
        # reload sway
        "${modifier}+Shift+c" = "exec swaymsg reload";
        # open powermenu
        "${modifier}+Shift+e" = "exec ${config.xdg.configHome}/rofi/powermenu/powermenu.sh";
        # open local send app
        "${modifier}+Shift+z" = "exec ${pkgs.localsend}/bin/localsend_app";
        # open rbw-rofi for password selection
        "${modifier}+Shift+w" = "exec ${pkgs.rofi-rbw-wayland}/bin/rofi-rbw";
        # open bitwarden GUI
        "${modifier}+Shift+p" = "exec ${pkgs.bitwarden-desktop}/bin/bitwarden";
        # open floating btop shell
        "${modifier}+Shift+t" =
          if config.terminal.floatingAppId != null
          then "exec ${config.terminal.bin} ${config.terminal.appIdFlag} ${config.terminal.floatingAppId} ${config.terminal.execFlag} ${pkgs.btop}/bin/btop"
          else "exec ${config.terminal.bin} ${config.terminal.execFlag} ${pkgs.btop}/bin/btop";
        # zooming and highlighting for screen share
        "${modifier}+Shift+y" = "exec ${pkgs.woomer}/bin/woomer";
        # open file managers
        "${modifier}+Shift+x" =
          if config.terminal.floatingAppId != null
          then "exec ${config.terminal.bin} ${config.terminal.appIdFlag} ${config.terminal.floatingAppId} ${config.terminal.execFlag} ${pkgs.yazi}/bin/yazi $(${config.xdg.configHome}/kitty/cwd.sh)"
          else "exec ${config.terminal.bin} ${config.terminal.execFlag} ${pkgs.yazi}/bin/yazi $(${config.xdg.configHome}/kitty/cwd.sh)";
        "${modifier}+Shift+n" = "exec ${pkgs.nemo-with-extensions}/bin/nemo $(${config.xdg.configHome}/kitty/cwd.sh)";
        # open terminals
        "${modifier}+Shift+Return" =
          if config.terminal.floatingAppId != null
          then "exec ${config.terminal.bin} ${config.terminal.appIdFlag} ${config.terminal.floatingAppId} ${config.terminal.workingDirFlag} $(${config.xdg.configHome}/kitty/cwd.sh)"
          else "exec ${config.terminal.bin} ${config.terminal.workingDirFlag} $(${config.xdg.configHome}/kitty/cwd.sh)";
        "${modifier}+Return" = "exec '${config.terminal.bin} ${config.terminal.workingDirFlag} $(${config.xdg.configHome}/kitty/cwd.sh)'";

        # Toggle waybar
        "${modifier}+Shift+b" = "exec ${config.xdg.configHome}/waybar/toggle-waybar.sh";

        # Brightness control
        "XF86MonBrightnessDown" = "exec ${pkgs.light}/bin/light -U 10";
        "XF86MonBrightnessUp" = "exec ${pkgs.light}/bin/light -A 10";

        # Volume control using wpctl (WirePlumber)
        "XF86AudioRaiseVolume" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+";
        "XF86AudioLowerVolume" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-";
        "XF86AudioMute" = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";

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
      input =
        {
          "*" = {
            xkb_options = "compose:menu";
            xkb_layout = "us";
            xkb_variant = ",";
          };
        }
        // (
          if host == "t480s"
          then {
            "1267:32:Elan_Touchpad" = {
              natural_scroll = "enabled";
              tap = "enabled";
            };
          }
          else if host == "spectre" || host == "portable"
          then {
            "1739:52912:SYNA32BF:00_06CB:CEB0_Touchpad" = {
              natural_scroll = "enabled";
              tap = "enabled";
              pointer_accel = "0.3";
            };
            "1267:11821:ELAN2513:00_04F3:2E2D_Stylus" = {
              map_to_output = "eDP-1";
            };
          }
          else {}
        );
      bars = [];
    };
  };
}
