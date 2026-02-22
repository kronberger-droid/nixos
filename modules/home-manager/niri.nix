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
    xwayland-satellite
    fuzzel
    niri
  ];

  xdg.configFile."niri/config.kdl".text = ''
    // Niri minimal config for testing
    // See: https://github.com/YaLTeR/niri/wiki/Configuration:-Overview

    input {
        keyboard {
            xkb {
                layout "us"
                options "compose:menu"
            }
        }

        ${
      if isNotebook
      then ''
        touchpad {
                tap
                natural-scroll
            }''
      else ""
    }

        mouse {
            // off disables acceleration, if needed
        }
    }

    // Output configuration is handled by kanshi

    layout {
        gaps 4
        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        default-column-width {
            proportion 0.5
        }

        focus-ring {
            width 2
            active-color "#${config.scheme.base0F}"
            inactive-color "#${config.scheme.base00}"
        }

        border {
            off
        }
    }

    // Spawn processes at startup
    spawn-at-startup "${pkgs.swaybg}/bin/swaybg" "-m" "fill" "-i" "${./sway/deathpaper.jpg}"
    spawn-at-startup "${pkgs.xwayland-satellite}/bin/xwayland-satellite"
    // Mako is started via systemd (services.nix)

    prefer-no-csd

    screenshot-path "~/Pictures/Screenshots/screenshot-%Y-%m-%d-%H-%M-%S.png"

    hotkey-overlay {
        skip-at-startup
    }

    binds {
        // ── Applications ──────────────────────────────────────
        ${modifier}+Return { spawn "${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.workingDirFlag} $(${config.xdg.configHome}/kitty/cwd.sh)"; }
        ${modifier}+D { spawn "${pkgs.rofi}/bin/rofi" "-show" "drun"; }
        ${modifier}+Shift+S { spawn "${pkgs.firefox}/bin/firefox"; }
        ${
      if config.terminal.floatingAppId != null
      then ''${modifier}+Shift+Return { spawn "${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.appIdFlag} ${config.terminal.floatingAppId} ${config.terminal.workingDirFlag} $(${config.xdg.configHome}/kitty/cwd.sh)"; }''
      else ''${modifier}+Shift+Return { spawn "${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.workingDirFlag} $(${config.xdg.configHome}/kitty/cwd.sh)"; }''
    }
        ${
      if config.terminal.floatingAppId != null
      then ''${modifier}+Shift+T { spawn "${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.appIdFlag} ${config.terminal.floatingAppId} ${config.terminal.execFlag} ${pkgs.btop}/bin/btop"; }''
      else ''${modifier}+Shift+T { spawn "${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.execFlag} ${pkgs.btop}/bin/btop"; }''
    }
        ${
      if config.terminal.floatingAppId != null
      then ''${modifier}+Shift+X { spawn "${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.appIdFlag} ${config.terminal.floatingAppId} ${config.terminal.execFlag} ${pkgs.yazi}/bin/yazi $(${config.xdg.configHome}/kitty/cwd.sh)"; }''
      else ''${modifier}+Shift+X { spawn "${pkgs.bash}/bin/bash" "-c" "${terminal} ${config.terminal.execFlag} ${pkgs.yazi}/bin/yazi $(${config.xdg.configHome}/kitty/cwd.sh)"; }''
    }
        ${modifier}+Shift+N { spawn "${pkgs.bash}/bin/bash" "-c" "${pkgs.nemo-with-extensions}/bin/nemo $(${config.xdg.configHome}/kitty/cwd.sh)"; }

        // ── Session ───────────────────────────────────────────
        ${modifier}+Shift+Q { close-window; }
        ${modifier}+Shift+E { quit; }
        Ctrl+Alt+Delete { quit; }
        ${modifier}+Shift+P { spawn "${pkgs.bitwarden-desktop}/bin/bitwarden"; }

        // ── Notifications ─────────────────────────────────────
        ${modifier}+Shift+D { spawn "${pkgs.mako}/bin/makoctl" "dismiss" "-a"; }

        // ── Screenshots ───────────────────────────────────────
        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        // ── UI ────────────────────────────────────────────────
        ${modifier}+Shift+Slash { show-hotkey-overlay; }
        ${modifier}+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

        // ── Focus (Mod) ───────────────────────────────────────
        ${modifier}+H     { focus-column-left; }
        ${modifier}+L     { focus-column-right; }
        ${modifier}+J     { focus-window-down; }
        ${modifier}+K     { focus-window-up; }
        ${modifier}+Left  { focus-column-left; }
        ${modifier}+Right { focus-column-right; }
        ${modifier}+Down  { focus-window-down; }
        ${modifier}+Up    { focus-window-up; }
        ${modifier}+Home  { focus-column-first; }
        ${modifier}+End   { focus-column-last; }

        // ── Move columns/windows (Mod+Shift) ────────────────────
        ${modifier}+Shift+H     { move-column-left; }
        ${modifier}+Shift+L     { move-column-right; }
        ${modifier}+Shift+J     { move-window-down; }
        ${modifier}+Shift+K     { move-window-up; }
        ${modifier}+Shift+Left  { move-column-left; }
        ${modifier}+Shift+Right { move-column-right; }
        ${modifier}+Shift+Down  { move-window-down; }
        ${modifier}+Shift+Up    { move-window-up; }
        ${modifier}+Shift+Home  { move-column-to-first; }
        ${modifier}+Shift+End   { move-column-to-last; }

        // ── Monitor focus (Mod+Ctrl) ─────────────────────────
        ${modifier}+Ctrl+H     { focus-monitor-left; }
        ${modifier}+Ctrl+L     { focus-monitor-right; }
        ${modifier}+Ctrl+K     { focus-monitor-up; }
        ${modifier}+Ctrl+J     { focus-monitor-down; }
        ${modifier}+Ctrl+Left  { focus-monitor-left; }
        ${modifier}+Ctrl+Right { focus-monitor-right; }
        ${modifier}+Ctrl+Up    { focus-monitor-up; }
        ${modifier}+Ctrl+Down  { focus-monitor-down; }

        // ── Move to monitor (Mod+Ctrl+Shift) ──────────────────
        ${modifier}+Ctrl+Shift+H     { move-column-to-monitor-left; }
        ${modifier}+Ctrl+Shift+L     { move-column-to-monitor-right; }
        ${modifier}+Ctrl+Shift+K     { move-column-to-monitor-up; }
        ${modifier}+Ctrl+Shift+J     { move-column-to-monitor-down; }
        ${modifier}+Ctrl+Shift+Left  { move-column-to-monitor-left; }
        ${modifier}+Ctrl+Shift+Right { move-column-to-monitor-right; }
        ${modifier}+Ctrl+Shift+Up    { move-column-to-monitor-up; }
        ${modifier}+Ctrl+Shift+Down  { move-column-to-monitor-down; }

        // ── Column sizing ─────────────────────────────────────
        ${modifier}+R { switch-preset-column-width; }
        ${modifier}+Shift+R { switch-preset-window-height; }
        ${modifier}+Ctrl+R { reset-window-height; }
        ${modifier}+F { maximize-column; }
        ${modifier}+Shift+F { fullscreen-window; }
        ${modifier}+Ctrl+F { expand-column-to-available-width; }
        ${modifier}+C { center-column; }
        ${modifier}+Minus { set-column-width "-10%"; }
        ${modifier}+Equal { set-column-width "+10%"; }
        ${modifier}+Shift+Minus { set-window-height "-10%"; }
        ${modifier}+Shift+Equal { set-window-height "+10%"; }

        // ── Column stacking ───────────────────────────────────
        ${modifier}+BracketLeft  { consume-or-expel-window-left; }
        ${modifier}+BracketRight { consume-or-expel-window-right; }
        ${modifier}+Comma  { consume-window-into-column; }
        ${modifier}+Period { expel-window-from-column; }

        // ── Tabs ──────────────────────────────────────────────
        ${modifier}+W { toggle-column-tabbed-display; }

        // ── Floating ──────────────────────────────────────────
        ${modifier}+V       { toggle-window-floating; }
        ${modifier}+Shift+V { switch-focus-between-floating-and-tiling; }

        // ── Workspaces (focus) ────────────────────────────────
        ${modifier}+1 { focus-workspace 1; }
        ${modifier}+2 { focus-workspace 2; }
        ${modifier}+3 { focus-workspace 3; }
        ${modifier}+4 { focus-workspace 4; }
        ${modifier}+5 { focus-workspace 5; }
        ${modifier}+6 { focus-workspace 6; }
        ${modifier}+7 { focus-workspace 7; }
        ${modifier}+8 { focus-workspace 8; }
        ${modifier}+9 { focus-workspace 9; }

        // ── Workspaces (move column to) ───────────────────────
        ${modifier}+Shift+1 { move-column-to-workspace 1; }
        ${modifier}+Shift+2 { move-column-to-workspace 2; }
        ${modifier}+Shift+3 { move-column-to-workspace 3; }
        ${modifier}+Shift+4 { move-column-to-workspace 4; }
        ${modifier}+Shift+5 { move-column-to-workspace 5; }
        ${modifier}+Shift+6 { move-column-to-workspace 6; }
        ${modifier}+Shift+7 { move-column-to-workspace 7; }
        ${modifier}+Shift+8 { move-column-to-workspace 8; }
        ${modifier}+Shift+9 { move-column-to-workspace 9; }

        // ── Workspace cycling ─────────────────────────────────
        ${modifier}+Page_Down { focus-workspace-down; }
        ${modifier}+Page_Up   { focus-workspace-up; }
        ${modifier}+U { focus-workspace-down; }
        ${modifier}+I { focus-workspace-up; }
        ${modifier}+Shift+Page_Down { move-column-to-workspace-down; }
        ${modifier}+Shift+Page_Up   { move-column-to-workspace-up; }
        ${modifier}+Shift+U { move-column-to-workspace-down; }
        ${modifier}+Shift+I { move-column-to-workspace-up; }

        // ── Workspace reordering ──────────────────────────────
        ${modifier}+Ctrl+Page_Down { move-workspace-down; }
        ${modifier}+Ctrl+Page_Up   { move-workspace-up; }
        ${modifier}+Ctrl+U { move-workspace-down; }
        ${modifier}+Ctrl+I { move-workspace-up; }

        // ── Mouse wheel (workspace) ──────────────────────────
        ${modifier}+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
        ${modifier}+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
        ${modifier}+Shift+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
        ${modifier}+Shift+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

        // ── Mouse wheel (columns) ────────────────────────────
        ${modifier}+WheelScrollRight      { focus-column-right; }
        ${modifier}+WheelScrollLeft       { focus-column-left; }
        ${modifier}+Shift+WheelScrollRight { move-column-right; }
        ${modifier}+Shift+WheelScrollLeft  { move-column-left; }
        ${modifier}+Ctrl+WheelScrollDown { focus-column-right; }
        ${modifier}+Ctrl+WheelScrollUp   { focus-column-left; }
        ${modifier}+Ctrl+Shift+WheelScrollDown { move-column-right; }
        ${modifier}+Ctrl+Shift+WheelScrollUp   { move-column-left; }

        // ── Volume and brightness ─────────────────────────────
        XF86AudioRaiseVolume allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+" "-l" "1.0"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"; }
        XF86AudioMute        allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioMicMute     allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
        XF86MonBrightnessUp   allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "--class=backlight" "set" "+10%"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "--class=backlight" "set" "10%-"; }

        // ── Media ─────────────────────────────────────────────
        XF86AudioNext allow-when-locked=true { spawn "${pkgs.waybar-mpris}/bin/waybar-mpris" "--send" "next"; }
        XF86AudioPrev allow-when-locked=true { spawn "${pkgs.waybar-mpris}/bin/waybar-mpris" "--send" "prev"; }
        XF86AudioPlay allow-when-locked=true { spawn "${pkgs.waybar-mpris}/bin/waybar-mpris" "--send" "toggle"; }
    }

    // Window rules
    window-rule {
        // Default all windows to slightly rounded corners
        geometry-corner-radius 4 4 4 4
        clip-to-geometry true
    }

    window-rule {
        match is-floating=true
        default-column-width { proportion 0.5; }
        default-window-height { proportion 0.6; }
    }

    window-rule {
        match app-id=r#"^floating_shell$"#
        open-floating true
    }

    window-rule {
        match app-id=r#"^nemo$"#
        open-floating true
        default-column-width { fixed 1200; }
        default-window-height { fixed 800; }
    }

    window-rule {
        match app-id=r#"^localsend_app$"#
        open-floating true
        default-column-width { fixed 1200; }
        default-window-height { fixed 800; }
    }

    window-rule {
        match app-id=r#"^Bitwarden$"#
        open-floating true
    }

    window-rule {
        match app-id=r#"^org\.speedcrunch$"#
        open-floating true
        default-column-width { fixed 800; }
        default-window-height { fixed 600; }
    }

    window-rule {
        match title=r#"(?i)(open|save) (file|folder|as)"#
        open-floating true
    }

    // Inactive window opacity (equivalent to sway's inactive-windows-transparency)
    window-rule {
        match is-focused=false
        opacity 0.95
    }
  '';
}
