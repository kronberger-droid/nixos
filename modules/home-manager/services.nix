{
  config,
  pkgs,
  lib,
  host,
  isNotebook,
  ...
}: let
  # Compositor-agnostic DPMS control script
  dpmsOff = pkgs.writeShellScript "dpms-off" ''
    if [ -n "$SWAYSOCK" ]; then
      ${pkgs.sway}/bin/swaymsg 'output * dpms off'
    elif [ -n "$NIRI_SOCKET" ]; then
      ${pkgs.niri}/bin/niri msg action power-off-monitors
    fi
  '';
  dpmsOn = pkgs.writeShellScript "dpms-on" ''
    if [ -n "$SWAYSOCK" ]; then
      ${pkgs.sway}/bin/swaymsg 'output * dpms on'
    elif [ -n "$NIRI_SOCKET" ]; then
      ${pkgs.niri}/bin/niri msg action power-on-monitors
    fi
  '';
in {
  imports = [
    ./sway/swaylock.nix
  ];

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
    gron
    lsof
    libinput
    xdg-user-dirs

    # Session services
    swayidle
    wayland-pipewire-idle-inhibit
    wlsunset
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

  # ── Poweralertd ─────────────────────────────────────────────────
  services.poweralertd = {
    enable =
      if host == "spectre"
      then true
      else false;
  };

  systemd.user.services.poweralertd = {
    Unit = {
      After = ["mako.service" "graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
  };

  # ── Swayidle ────────────────────────────────────────────────────
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
        command = "${dpmsOff}";
        resumeCommand = "${dpmsOn}";
      }
      {
        timeout = 560;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
    events = {
      "before-sleep" = "${pkgs.swaylock-effects}/bin/swaylock -f &";
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

  # ── Polkit agent ────────────────────────────────────────────────
  systemd.user.services.polkit-kde-agent = {
    Unit = {
      Description = "PolicyKit Authentication Agent";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
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

      # Polling interval in milliseconds
      # How often to check the accelerometer
      poll-interval = 500

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
