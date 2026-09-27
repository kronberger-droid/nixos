{
  config,
  pkgs,
  lib,
  isNotebook,
  hasAccelerometer,
  osConfig ? null,
  ...
}: let
  # Idle sleep action. Mirrors logind's lid handling in
  # modules/system/hardware/power-management.nix: hosts that declare a
  # resume device get suspend-then-hibernate, the rest plain suspend.
  # Going through `systemctl` here bypasses logind's IdleAction, which never
  # fires on Wayland anyway (the compositor does not set the session IdleHint).
  idleSleep =
    if (osConfig.boot.resumeDevice or "") != ""
    then "suspend-then-hibernate"
    else "suspend";

  # DPMS control, dispatching on whichever compositor's socket is live. The niri
  # branch interpolates ${pkgs.niri} (the source-built fork), so only emit it
  # when niri is the primary compositor — otherwise it drags the fork into the
  # closure of sway-only hosts for a code path that never runs there.
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

  # Manual idle inhibit, one holder per compositor; see idle-inhibit.service
  # below for why there are two. The niri holder takes an
  # org.freedesktop.ScreenSaver Inhibit and then just keeps its bus
  # connection open: niri drops the inhibit the moment that connection goes
  # away, so the SIGTERM from `systemctl stop` is the release.
  idleInhibitDbus = pkgs.writers.writePython3 "idle-inhibit-dbus" {
    libraries = [pkgs.python3Packages.jeepney];
  } ''
    import signal

    from jeepney import DBusAddress, new_method_call
    from jeepney.io.blocking import open_dbus_connection

    SCREENSAVER = DBusAddress(
        "/ScreenSaver",
        bus_name="org.freedesktop.ScreenSaver",
        interface="org.freedesktop.ScreenSaver",
    )

    conn = open_dbus_connection(bus="SESSION")
    conn.send_and_get_reply(
        new_method_call(SCREENSAVER, "Inhibit", "ss", ("eww", "idle toggle"))
    )
    # Hold the connection open; closing it releases the inhibit.
    signal.pause()
  '';
  idleInhibit = pkgs.writeShellScript "idle-inhibit" ''
    if [ -n "$NIRI_SOCKET" ] && [ -S "$NIRI_SOCKET" ]; then
      exec ${idleInhibitDbus}
    fi
    exec ${pkgs.wlinhibit}/bin/wlinhibit
  '';

  # Second line of defence behind `hasAccelerometer`, which already keeps this
  # whole block off hosts without the sensor. Kept because it still carries
  # the waybar opt-out toggle, and because a host can claim the sensor while
  # firmware declines to enumerate it, which is the case rot8 handles worst:
  # it exits 1 with "Unknown Accelerometer Device" immediately, and
  # Restart=on-failure turns that into an endless respawn loop. A non-zero
  # ExecCondition marks the unit skipped rather than failed, so Restart never
  # applies and the loop becomes a single clean skip.
  rot8Condition = pkgs.writeShellScript "rot8-condition" ''
    # Explicit opt-out via the waybar rotation toggle.
    [ -f "$HOME/.cache/rotation-state" ] && exit 1
    for f in /sys/bus/iio/devices/iio:device*/in_accel_*_raw; do
      [ -e "$f" ] && exit 0
    done
    exit 1
  '';
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

    # Image viewer: xdg.nix's image/* default and yazi's opener. Compositor
    # agnostic despite the name, so it lives here rather than in sway.nix,
    # which is gated on compositor.primary.
    swayimg
    # `magick` backs the nushell color-picker helper (grim | magick). It used
    # to ride along in terminals/kitty.nix, which is gated on the emulator
    # now, so it lives with the other screen tools.
    imagemagick
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
        command = "${config.programs.swaylock.package}/bin/swaylock -f";
      }
      {
        timeout = 460;
        command = "${dpmsOff}";
        resumeCommand = "${dpmsOn}";
      }
      {
        timeout = 560;
        command = "${pkgs.systemd}/bin/systemctl ${idleSleep}";
      }
    ];
    events = {
      "before-sleep" = "${config.programs.swaylock.package}/bin/swaylock -f";
      "after-resume" = "${dpmsOn}";
    };
  };

  # ── Audio idle inhibit ──────────────────────────────────────────
  systemd.user.services.wayland-pipewire-idle-inhibit = {
    Unit = {
      Description = "Inhibit idle when audio is playing";
      # wireplumber is what creates the ALSA sinks. Started in the same
      # second as it, the daemon came up with no sink at all ("List of sinks
      # is empty"), and days later that instance no longer inhibited anything
      # while a fresh start worked at once. Ordering after wireplumber gives
      # it the sink from the start.
      After = ["pipewire.service" "wireplumber.service" "graphical-session.target"];
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

  # ── Manual idle inhibit ─────────────────────────────────────────
  # Backs the eww bar's idle toggle (eww/nu/idle.nu). Holding an inhibit
  # pauses every swayidle timeout but leaves swayidle itself alone:
  # before-sleep still fires on a lid close, so an inhibited session still
  # locks when logind suspends it. The toggle used to stop swayidle.service
  # outright, which took that hook down with the timers and left the machine
  # unlocked after every sleep while the toggle was on.
  #
  # The holder depends on the compositor. wlinhibit takes a
  # zwp_idle_inhibitor_v1 on a surface it never maps; sway counts a
  # role-less inhibitor as visible, so that is enough there. niri only
  # honours an inhibitor whose surface was presented in the last rendered
  # frame (Niri::refresh_idle_inhibit), so it ignores wlinhibit outright:
  # the bar showed "inhibited" for two days while the timers kept firing.
  # niri does serve org.freedesktop.ScreenSaver on the session bus, though,
  # and that path needs no surface, so on niri the unit holds a D-Bus
  # Inhibit instead (idleInhibit above picks by NIRI_SOCKET).
  #
  # Not WantedBy anything: the toggle starts and stops it, and is-active is
  # the toggle's state. PartOf makes a session teardown clear the inhibit.
  systemd.user.services.idle-inhibit = {
    Unit = {
      Description = "Hold an idle inhibitor";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };

    Service = {
      ExecStart = "${idleInhibit}";
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

  # ── Clipboard persistence ──────────────────────────────────────
  # Wayland clipboards belong to the source window: close the terminal you
  # copied from and the selection is gone. That bites with rio's
  # copy-on-select and with rofi-rbw's clear-after flow (a password copied
  # in a window you then close). wl-clip-persist re-owns the regular
  # clipboard only; the primary selection is left alone so select-to-copy
  # keeps its usual semantics.
  systemd.user.services.wl-clip-persist = {
    Unit = {
      Description = "Keep the Wayland clipboard after the source window closes";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };

  # ── Rot8 (hosts with an accelerometer only) ────────────────────
  xdg.configFile."rot8/rot8.toml" = lib.mkIf hasAccelerometer {
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

  systemd.user.services.rot8 = lib.mkIf hasAccelerometer {
    Unit = {
      Description = "Auto-rotate screen based on accelerometer";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
      # Backstop for any *other* persistent failure. The default burst of 5 is
      # useless next to RestartSec=5, because five restarts span 25s and the
      # default 10s window never sees more than two.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };

    Service = {
      # Skip cleanly unless rotation is enabled and an accelerometer exists.
      ExecCondition = "${rot8Condition}";
      ExecStart = "${pkgs.rot8}/bin/rot8";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
