{
  config,
  pkgs,
  lib,
  isNotebook,
  ...
}: let
  # DPMS control, dispatching on whichever compositor's socket is live. The niri
  # branch interpolates ${pkgs.niri} (the source-built fork), so only emit it
  # when niri is the primary compositor — otherwise it drags the fork into the
  # closure of sway-only hosts (mediaBox) for a code path that never runs there.
  niriPrimary = config.compositor.primary == "niri";
  dpms = name: niriAction: swayState:
    pkgs.writeShellScript name ''
      ${lib.optionalString niriPrimary ''
        if [ -n "$NIRI_SOCKET" ] && [ -S "$NIRI_SOCKET" ]; then
          ${pkgs.niri}/bin/niri msg action ${niriAction}
          exit 0
        fi
      ''}
      if [ -n "$SWAYSOCK" ] && [ -S "$SWAYSOCK" ]; then
        ${pkgs.sway}/bin/swaymsg 'output * dpms ${swayState}'
      fi
    '';
  dpmsOff = dpms "dpms-off" "power-off-monitors" "off";
  dpmsOn = dpms "dpms-on" "power-on-monitors" "on";
in {
  imports = [
    ./sway/swaylock.nix
  ];

  home.file.".config/swappy/config".text = ''
    [Default]
    save_dir=$HOME/Pictures/Screenshots
    save_filename_format=swappy-%Y-%m-%d-%H-%M-%S.png
    show_panel=false
    line_size=5
    text_size=15
    text_font=monospace
    paint_mode=rectangle
    early_exit=true
    fill_shape=false
  '';

  home.packages = with pkgs; [
    # Shared wayland session packages (used by both sway and niri)
    wl-clipboard
    brightnessctl
    grim
    slurp
    swappy
    swaybg
    libnotify
    jq
    lsof
    libinput
    xdg-user-dirs

    # Session services
    swayidle
    wayland-pipewire-idle-inhibit
    wlsunset

    # Screen recording
    wl-screenrec
  ];

  # ── Mako ────────────────────────────────────────────────────────
  services.mako = {
    enable = true;
    settings = {
      default-timeout = "10000";
      border-radius = "8";
      border-color = "#${config.scheme.base0D}";
      background-color = "#${config.scheme.base00}";
      text-color = "#${config.scheme.base05}";
      "urgency=high" = {
        border-color = "#${config.scheme.base08}";
      };
      "urgency=low" = {
        border-color = "#${config.scheme.base03}";
      };
    };
  };

  # ── Batsignal ───────────────────────────────────────────────────
  services.batsignal = {
    enable = isNotebook;
  };

  # ── Swayidle ────────────────────────────────────────────────────
  services.swayidle = {
    enable = true;
    systemdTargets = ["graphical-session.target"];
    timeouts = [
      {
        timeout = 380;
        command = "${pkgs.libnotify}/bin/notify-send -u critical 'Locking in 20 seconds' -t 18000";
      }
      {
        timeout = 400;
        command = "${pkgs.swaylock-effects}/bin/swaylock -f";
      }
      {
        timeout = 460;
        command = "${dpmsOff}";
        resumeCommand = "${dpmsOn}";
      }
      {
        timeout = 560;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
    events = {
      "before-sleep" = "${pkgs.swaylock-effects}/bin/swaylock -f";
      "after-resume" = "${dpmsOn}";
    };
  };

  # ── Audio idle inhibit ──────────────────────────────────────────
  systemd.user.services.wayland-pipewire-idle-inhibit = {
    Unit = {
      Description = "Inhibit idle when audio is playing";
      After = ["pipewire.service" "graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${pkgs.wayland-pipewire-idle-inhibit}/bin/wayland-pipewire-idle-inhibit";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };

  # ── XWayland Satellite ──────────────────────────────────────────
  systemd.user.services.xwayland-satellite = {
    Unit = {
      Description = "XWayland outside your Wayland";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecCondition = "${pkgs.bash}/bin/bash -c '[ -n \"$NIRI_SOCKET\" ]'";
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite :11";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };

  # ── Wlsunset ───────────────────────────────────────────────────
  systemd.user.services.wlsunset = {
    Unit = {
      Description = "Day/night gamma adjustments";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${pkgs.wlsunset}/bin/wlsunset -l 48.2 -L 16.4";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };

  # ── Rot8 (notebooks only) ──────────────────────────────────────
  xdg.configFile."rot8/rot8.toml" = lib.mkIf isNotebook {
    text = ''
      # rot8 configuration for HP Spectre x360
      # Auto-rotation daemon

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

      # Polling interval in milliseconds.
      # 1 Hz is plenty for screen rotation responsiveness and halves the
      # wakeup rate vs the upstream default of 500 ms.
      poll-interval = 1000

      # Allow all orientations (normal, left, right, inverted)
      # Set to false to disable upside-down rotation
      invert-mode = true
    '';
  };

  systemd.user.services.rot8 = lib.mkIf isNotebook {
    Unit = {
      Description = "Auto-rotate screen based on accelerometer";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      # Only start if rotation is not disabled
      ExecCondition = "${pkgs.bash}/bin/bash -c '[ ! -f $HOME/.cache/rotation-state ]'";
      ExecStart = "${pkgs.rot8}/bin/rot8";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
