{
  config,
  pkgs,
  lib,
  host,
  isNotebook,
  ...
}: let
  modifier = "Mod";
  terminal = config.terminal.bin;
in {
  home.packages = with pkgs; [
    fuzzel
  ];

  programs.niri.settings = {
    environment = {
      DISPLAY = ":0";
    };

    # Input configuration
    input = {
      keyboard = {
        xkb = {
          layout = "us";
          options = "compose:menu";
        };
      };

      touchpad = lib.mkIf isNotebook {
        tap = true;
        natural-scroll = true;
      };

      mouse = {};
    };

    # Layout configuration
    layout = {
      gaps = 4;
      center-focused-column = "never";
      struts = {
        left = 2;
        right = 2;
      };

      preset-column-widths = [
        {proportion = 0.33333;}
        {proportion = 0.5;}
        {proportion = 0.66667;}
      ];

      default-column-width = {
        proportion = 0.5;
      };

      focus-ring = {
        width = 2;
        active.color = "#${config.scheme.base0F}";
        inactive.color = "#${config.scheme.base00}";
      };

      border = {
        enable = false;
      };

      tab-indicator = {
        position = "top";
        place-within-column = true;
      };
    };

    # Startup commands
    spawn-at-startup = [
      {command = ["${pkgs.swaybg}/bin/swaybg" "-m" "fill" "-i" "${./sway/deathpaper.jpg}"];}
      {command = ["${pkgs.xwayland-satellite}/bin/xwayland-satellite"];}
    ];

    animations = {
      workspace-switch.kind.spring = {
        damping-ratio = 1.0;
        stiffness = 8000;
        epsilon = 0.001;
      };
      window-open.kind.easing = {
        duration-ms = 60;
        curve = "ease-out-expo";
      };
      window-close.kind.easing = {
        duration-ms = 40;
        curve = "ease-out-expo";
      };
      horizontal-view-movement.kind.spring = {
        damping-ratio = 1.0;
        stiffness = 8000;
        epsilon = 0.001;
      };
      window-movement.kind.spring = {
        damping-ratio = 1.0;
        stiffness = 8000;
        epsilon = 0.001;
      };
      window-resize.kind.spring = {
        damping-ratio = 1.0;
        stiffness = 8000;
        epsilon = 0.001;
      };
      config-notification-open-close.enable = false;
    };

    prefer-no-csd = true;

    screenshot-path = "~/Pictures/Screenshots/screenshot-%Y-%m-%d-%H-%M-%S.png";

    hotkey-overlay = {
      skip-at-startup = true;
    };

    # Keybindings
    binds = {
      # Applications
      "${modifier}+Return".action.spawn = ["${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.workingDirFlag} $(${config.xdg.configHome}/kitty/cwd.sh)"];
      "${modifier}+D".action.spawn = ["${pkgs.rofi}/bin/rofi" "-show" "drun"];
      "${modifier}+Shift+S".action.spawn = ["${pkgs.firefox}/bin/firefox"];
      "${modifier}+Shift+Return".action.spawn =
        if config.terminal.floatingAppId != null
        then ["${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.appIdFlag} ${config.terminal.floatingAppId} ${config.terminal.workingDirFlag} $(${config.xdg.configHome}/kitty/cwd.sh)"]
        else ["${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.workingDirFlag} $(${config.xdg.configHome}/kitty/cwd.sh)"];
      "${modifier}+Shift+T".action.spawn =
        if config.terminal.floatingAppId != null
        then ["${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.appIdFlag} ${config.terminal.floatingAppId} ${config.terminal.execFlag} ${pkgs.btop}/bin/btop"]
        else ["${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.execFlag} ${pkgs.btop}/bin/btop"];
      "${modifier}+Shift+X".action.spawn =
        if config.terminal.floatingAppId != null
        then ["${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.appIdFlag} ${config.terminal.floatingAppId} ${config.terminal.execFlag} ${pkgs.yazi}/bin/yazi $(${config.xdg.configHome}/kitty/cwd.sh)"]
        else ["${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.execFlag} ${pkgs.yazi}/bin/yazi $(${config.xdg.configHome}/kitty/cwd.sh)"];
      "${modifier}+Shift+N".action.spawn = ["${pkgs.bash}/bin/bash" "-c" "${pkgs.nemo-with-extensions}/bin/nemo $(${config.xdg.configHome}/kitty/cwd.sh)"];

      # Session
      "${modifier}+Shift+Q".action.close-window = [];
      "${modifier}+Shift+E".action.spawn = ["${config.xdg.configHome}/rofi/powermenu/powermenu.sh"];
      "${modifier}+Shift+P".action.spawn = ["${pkgs.bitwarden-desktop}/bin/bitwarden"];
      "${modifier}+Shift+W".action.spawn = ["${pkgs.rofi-rbw-wayland}/bin/rofi-rbw"];

      # Notifications
      "${modifier}+Shift+D".action.spawn = ["${pkgs.mako}/bin/makoctl" "dismiss" "-a"];

      # Screenshots
      "Print".action.screenshot = [];
      "Ctrl+Print".action.screenshot-screen = [];
      "Alt+Print".action.screenshot-window = [];

      # UI
      "${modifier}+Shift+Slash".action.show-hotkey-overlay = [];
      "${modifier}+Escape" = {
        allow-inhibiting = false;
        action.toggle-keyboard-shortcuts-inhibit = [];
      };

      # Focus (Mod)
      "${modifier}+H".action.focus-column-left = [];
      "${modifier}+L".action.focus-column-right = [];
      "${modifier}+J".action.focus-window-down = [];
      "${modifier}+K".action.focus-window-up = [];
      "${modifier}+Left".action.focus-column-left = [];
      "${modifier}+Right".action.focus-column-right = [];
      "${modifier}+Down".action.focus-window-down = [];
      "${modifier}+Up".action.focus-window-up = [];
      "${modifier}+Home".action.focus-column-first = [];
      "${modifier}+End".action.focus-column-last = [];

      # Move columns/windows (Mod+Shift)
      "${modifier}+Shift+H".action.move-column-left = [];
      "${modifier}+Shift+L".action.move-column-right = [];
      "${modifier}+Shift+J".action.move-window-down = [];
      "${modifier}+Shift+K".action.move-window-up = [];
      "${modifier}+Shift+Left".action.move-column-left = [];
      "${modifier}+Shift+Right".action.move-column-right = [];
      "${modifier}+Shift+Down".action.move-window-down = [];
      "${modifier}+Shift+Up".action.move-window-up = [];
      "${modifier}+Shift+Home".action.move-column-to-first = [];
      "${modifier}+Shift+End".action.move-column-to-last = [];

      # Monitor focus (Mod+Ctrl)
      "${modifier}+Ctrl+H".action.focus-monitor-left = [];
      "${modifier}+Ctrl+L".action.focus-monitor-right = [];
      "${modifier}+Ctrl+K".action.focus-monitor-up = [];
      "${modifier}+Ctrl+J".action.focus-monitor-down = [];
      "${modifier}+Ctrl+Left".action.focus-monitor-left = [];
      "${modifier}+Ctrl+Right".action.focus-monitor-right = [];
      "${modifier}+Ctrl+Up".action.focus-monitor-up = [];
      "${modifier}+Ctrl+Down".action.focus-monitor-down = [];

      # Move to monitor (Mod+Ctrl+Shift)
      "${modifier}+Ctrl+Shift+H".action.move-column-to-monitor-left = [];
      "${modifier}+Ctrl+Shift+L".action.move-column-to-monitor-right = [];
      "${modifier}+Ctrl+Shift+K".action.move-column-to-monitor-up = [];
      "${modifier}+Ctrl+Shift+J".action.move-column-to-monitor-down = [];
      "${modifier}+Ctrl+Shift+Left".action.move-column-to-monitor-left = [];
      "${modifier}+Ctrl+Shift+Right".action.move-column-to-monitor-right = [];
      "${modifier}+Ctrl+Shift+Up".action.move-column-to-monitor-up = [];
      "${modifier}+Ctrl+Shift+Down".action.move-column-to-monitor-down = [];

      # Column sizing
      "${modifier}+R".action.switch-preset-column-width = [];
      "${modifier}+Shift+R".action.switch-preset-window-height = [];
      "${modifier}+Ctrl+R".action.reset-window-height = [];
      "${modifier}+F".action.maximize-column = [];
      "${modifier}+Shift+F".action.fullscreen-window = [];
      "${modifier}+Ctrl+F".action.expand-column-to-available-width = [];
      "${modifier}+C".action.center-column = [];
      "${modifier}+Minus".action.set-column-width = "-10%";
      "${modifier}+Equal".action.set-column-width = "+10%";
      "${modifier}+Shift+Minus".action.set-window-height = "-10%";
      "${modifier}+Shift+Equal".action.set-window-height = "+10%";

      # Column stacking
      "${modifier}+BracketLeft".action.consume-or-expel-window-left = [];
      "${modifier}+BracketRight".action.consume-or-expel-window-right = [];
      "${modifier}+Comma".action.consume-window-into-column = [];
      "${modifier}+Period".action.expel-window-from-column = [];

      # Tabs
      "${modifier}+W".action.toggle-column-tabbed-display = [];

      # Floating
      "${modifier}+Space".action.switch-focus-between-floating-and-tiling = [];
      "${modifier}+Shift+Space".action.toggle-window-floating = [];

      # Workspaces (focus)
      "${modifier}+1".action.focus-workspace = 1;
      "${modifier}+2".action.focus-workspace = 2;
      "${modifier}+3".action.focus-workspace = 3;
      "${modifier}+4".action.focus-workspace = 4;
      "${modifier}+5".action.focus-workspace = 5;
      "${modifier}+6".action.focus-workspace = 6;
      "${modifier}+7".action.focus-workspace = 7;
      "${modifier}+8".action.focus-workspace = 8;
      "${modifier}+9".action.focus-workspace = 9;

      # Workspaces (move column to)
      "${modifier}+Shift+1".action.move-column-to-workspace = 1;
      "${modifier}+Shift+2".action.move-column-to-workspace = 2;
      "${modifier}+Shift+3".action.move-column-to-workspace = 3;
      "${modifier}+Shift+4".action.move-column-to-workspace = 4;
      "${modifier}+Shift+5".action.move-column-to-workspace = 5;
      "${modifier}+Shift+6".action.move-column-to-workspace = 6;
      "${modifier}+Shift+7".action.move-column-to-workspace = 7;
      "${modifier}+Shift+8".action.move-column-to-workspace = 8;
      "${modifier}+Shift+9".action.move-column-to-workspace = 9;

      # Workspace cycling
      "${modifier}+Page_Down".action.focus-workspace-down = [];
      "${modifier}+Page_Up".action.focus-workspace-up = [];
      "${modifier}+U".action.focus-workspace-down = [];
      "${modifier}+I".action.focus-workspace-up = [];
      "${modifier}+Shift+Page_Down".action.move-column-to-workspace-down = [];
      "${modifier}+Shift+Page_Up".action.move-column-to-workspace-up = [];
      "${modifier}+Shift+U".action.move-column-to-workspace-down = [];
      "${modifier}+Shift+I".action.move-column-to-workspace-up = [];

      # Workspace reordering
      "${modifier}+Ctrl+Page_Down".action.move-workspace-down = [];
      "${modifier}+Ctrl+Page_Up".action.move-workspace-up = [];
      "${modifier}+Ctrl+U".action.move-workspace-down = [];
      "${modifier}+Ctrl+I".action.move-workspace-up = [];

      # Mouse wheel (workspace)
      "${modifier}+WheelScrollDown" = {
        cooldown-ms = 150;
        action.focus-workspace-down = [];
      };
      "${modifier}+WheelScrollUp" = {
        cooldown-ms = 150;
        action.focus-workspace-up = [];
      };
      "${modifier}+Shift+WheelScrollDown" = {
        cooldown-ms = 150;
        action.move-column-to-workspace-down = [];
      };
      "${modifier}+Shift+WheelScrollUp" = {
        cooldown-ms = 150;
        action.move-column-to-workspace-up = [];
      };

      # Mouse wheel (columns)
      "${modifier}+WheelScrollRight".action.focus-column-right = [];
      "${modifier}+WheelScrollLeft".action.focus-column-left = [];
      "${modifier}+Shift+WheelScrollRight".action.move-column-right = [];
      "${modifier}+Shift+WheelScrollLeft".action.move-column-left = [];
      "${modifier}+Ctrl+WheelScrollDown".action.focus-column-right = [];
      "${modifier}+Ctrl+WheelScrollUp".action.focus-column-left = [];
      "${modifier}+Ctrl+Shift+WheelScrollDown".action.move-column-right = [];
      "${modifier}+Ctrl+Shift+WheelScrollUp".action.move-column-left = [];

      # Volume and brightness
      "XF86AudioRaiseVolume" = {
        allow-when-locked = true;
        action.spawn = ["${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+" "-l" "1.0"];
      };
      "XF86AudioLowerVolume" = {
        allow-when-locked = true;
        action.spawn = ["${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"];
      };
      "XF86AudioMute" = {
        allow-when-locked = true;
        action.spawn = ["${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"];
      };
      "XF86AudioMicMute" = {
        allow-when-locked = true;
        action.spawn = ["${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"];
      };
      "XF86MonBrightnessUp" = {
        allow-when-locked = true;
        action.spawn = ["${pkgs.brightnessctl}/bin/brightnessctl" "--class=backlight" "set" "+10%"];
      };
      "XF86MonBrightnessDown" = {
        allow-when-locked = true;
        action.spawn = ["${pkgs.brightnessctl}/bin/brightnessctl" "--class=backlight" "set" "10%-"];
      };

      # Media
      "XF86AudioNext" = {
        allow-when-locked = true;
        action.spawn = ["${pkgs.waybar-mpris}/bin/waybar-mpris" "--send" "next"];
      };
      "XF86AudioPrev" = {
        allow-when-locked = true;
        action.spawn = ["${pkgs.waybar-mpris}/bin/waybar-mpris" "--send" "prev"];
      };
      "XF86AudioPlay" = {
        allow-when-locked = true;
        action.spawn = ["${pkgs.waybar-mpris}/bin/waybar-mpris" "--send" "toggle"];
      };
    };

    # Window rules
    window-rules = [
      # Default all windows to slightly rounded corners
      {
        geometry-corner-radius = {
          top-left = 4.0;
          top-right = 4.0;
          bottom-left = 4.0;
          bottom-right = 4.0;
        };
        clip-to-geometry = true;
      }

      # Floating windows default size
      {
        matches = [{is-floating = true;}];
        default-column-width = {proportion = 0.5;};
        default-window-height = {proportion = 0.6;};
      }

      # Floating shell
      {
        matches = [{app-id = "^floating_shell$";}];
        open-floating = true;
        default-column-width = {proportion = 0.5;};
        default-window-height = {proportion = 0.6;};
      }

      # Nemo file manager
      {
        matches = [{app-id = "^nemo$";}];
        open-floating = true;
        default-column-width = {proportion = 0.5;};
        default-window-height = {proportion = 0.6;};
      }

      # LocalSend
      {
        matches = [{app-id = "^localsend_app$";}];
        open-floating = true;
        default-column-width = {fixed = 1200;};
        default-window-height = {fixed = 800;};
      }

      # Bitwarden
      {
        matches = [{app-id = "^Bitwarden$";}];
        open-floating = true;
        default-column-width = {proportion = 0.5;};
        default-window-height = {proportion = 0.6;};
      }

      # File dialogs
      {
        matches = [{title = "(?i)(open|save) (file|folder|as)";}];
        open-floating = true;
        default-column-width = {proportion = 0.5;};
        default-window-height = {proportion = 0.6;};
      }

      # Inactive window opacity
      {
        matches = [{is-focused = false;}];
        opacity = 0.95;
      }
    ];
  };
}
