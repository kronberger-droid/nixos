{
  dropkittenPkg,
  config,
  pkgs,
  isNotebook,
  lib,
  ...
}: let

  dropkitten_size = {
    width = "0.35";
    height = "0.45";
  };

  dropkittenCmd = cmd: "${dropkittenPkg}/bin/dropkitten -t ${config.terminal.emulator} -W ${dropkitten_size.width} -H ${dropkitten_size.height} $(if [ -n \"$SWAYSOCK\" ]; then echo '-y 35'; fi) -- ${cmd}";

  # nmtui color scheme matching kitty theme
  nmtui_colors = "root=white,black:window=white,black:border=blue,black:listbox=white,black:actlistbox=black,blue:label=white,black:title=brightblue,black:button=white,black:actbutton=black,blue:compactbutton=white,black:checkbox=white,black:actcheckbox=black,blue:entry=white,black:textbox=white,black";

  # Helper scripts live as real .sh files under ./waybar/ instead of inline Nix
  # strings, so they stay syntax-highlighted and shellcheck-able and need no
  # ''${} escaping. Store paths arrive as replaceVars placeholders (@bash@,
  # @procps@, …), which is a plain textual substitution — the generated scripts
  # are byte-identical to the inlined ones. replaceVars fails the build both on
  # an unfilled @var@ and on an unused attr, so the lists below cannot drift
  # away from the scripts they fill in.
  script = name: vars: {
    executable = true;
    source = pkgs.replaceVars ./waybar/${name} vars;
  };

  # scratchpad-toggle and ncspot-toggle both spawn the configured terminal.
  terminalVars = {
    terminalBin = config.terminal.bin;
    terminalAppIdFlag = config.terminal.appIdFlag;
    terminalExecFlag = config.terminal.execFlag;
  };

  tui = {
    bluetooth = "${pkgs.bluetuith}/bin/bluetuith";
    wifi = "${pkgs.bash}/bin/bash -c 'NEWT_COLORS=\"${nmtui_colors}\" ${pkgs.networkmanager}/bin/nmtui connect'";
    audio = "${pkgs.wiremix}/bin/wiremix";
    calendar = "${pkgs.calcurse}/bin/calcurse";
    monitor = "${pkgs.btop}/bin/btop";
  };
in {
  home.packages = with pkgs; [
    waybar-mpris
    calcurse
    rofi
  ];

  xdg.configFile = {
    "waybar/toggle-waybar.sh".source = ./waybar/toggle-waybar.sh;

    "waybar/rotation-status.sh" = script "rotation-status.sh" {
      inherit (pkgs) bash;
    };

    "waybar/rotation-toggle.sh" = script "rotation-toggle.sh" {
      inherit (pkgs) bash coreutils rot8 libnotify procps;
    };

    "waybar/screenrec-toggle.sh" = script "screenrec-toggle.sh" {
      inherit (pkgs) bash procps libnotify rofi slurp gnugrep coreutils;
      wlScreenrec = pkgs.wl-screenrec;
    };

    "waybar/screenrec-status.sh" = script "screenrec-status.sh" {
      inherit (pkgs) bash procps;
    };

    "waybar/vpn-status.sh" = script "vpn-status.sh" {
      inherit (pkgs) bash tailscale systemd;
    };

    "waybar/vpn-disconnect-all.sh" = script "vpn-disconnect-all.sh" {
      inherit (pkgs) bash libnotify tailscale systemd procps;
    };

    "waybar/vpn-picker.sh" = script "vpn-picker.sh" {
      inherit (pkgs) bash libnotify procps tailscale systemd rofi sd coreutils;
    };

    "waybar/scratchpad-toggle.sh" =
      script "scratchpad-toggle.sh" (terminalVars
        // {inherit (pkgs) bash jq coreutils zellij procps;});

    "waybar/scratchpad-status.sh" = script "scratchpad-status.sh" {
      inherit (pkgs) bash jq;
    };

    "waybar/ncspot-toggle.sh" =
      script "ncspot-toggle.sh" (terminalVars
        // {inherit (pkgs) bash jq coreutils zellij;});

    "waybar/dnd-status.sh" = script "dnd-status.sh" {
      inherit (pkgs) bash mako ripgrep;
    };

    "waybar/dnd-toggle.sh" = script "dnd-toggle.sh" {
      inherit (pkgs) bash mako ripgrep libnotify procps;
    };
  };

  # Drive scratchpad/ncspot status updates from niri's event stream instead
  # of polling every 2 seconds. Signals waybar (RTMIN+12) on any window event.
  # niri-only: interpolating ${pkgs.niri-unstable} forces the (source-built)
  # niri fork into the closure, so gate it on the primary compositor to keep it
  # off sway hosts like mediaBox.
  systemd.user.services.niri-window-watcher = lib.mkIf (config.compositor.primary == "niri") {
    Unit = {
      Description = "Watch niri window events and signal waybar";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.writeShellScript "niri-window-watcher" ''
        ${pkgs.niri-unstable}/bin/niri msg event-stream | while IFS= read -r line; do
          case "$line" in
            'Window closed:'*|'Window opened or changed:'*'app_id: Some("scratchpad")'*)
              ${pkgs.procps}/bin/pkill -RTMIN+12 waybar 2>/dev/null || true
              ;;
          esac
        done
      ''}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      targets = ["graphical-session.target"];
    };
    style = let
      # Define base16 color variables with opacity variants
      colors = with config.scheme; ''
        @define-color base00 #${base00};
        @define-color base01 #${base01};
        @define-color base02 #${base02};
        @define-color base03 #${base03};
        @define-color base04 #${base04};
        @define-color base05 #${base05};
        @define-color base06 #${base06};
        @define-color base07 #${base07};
        @define-color base08 #${base08};
        @define-color base09 #${base09};
        @define-color base0A #${base0A};
        @define-color base0B #${base0B};
        @define-color base0C #${base0C};
        @define-color base0D #${base0D};
        @define-color base0E #${base0E};
        @define-color base0F #${base0F};
        @define-color base00E6 rgba(30, 30, 30, 0.9);
        @define-color base01E6 rgba(44, 47, 51, 0.9);
        @define-color base0FE6 rgba(138, 129, 119, 0.9);

      '';
    in
      pkgs.writeText "waybar-style.css" ''
        ${colors}${builtins.readFile ./waybar/style.css}
      '';
    settings = [
      {
        height = 30;
        layer = "top";
        position = "top";
        tray = {
          spacing = 10;
          icon-size = 14;
        };
        modules-left = ["custom/menu" "sway/workspaces" "niri/workspaces" "custom/scratchpad" "sway/scratchpad" "sway/mode"];
        modules-right =
          [
            "group/toggles-cluster"
          ]
          ++ [
            "custom/separator"
            "bluetooth"
            "pulseaudio"
            "custom/mpris"
            "custom/separator"
            "network"
            "custom/vpn"
            "custom/separator"
            "cpu"
          ]
          ++ lib.optionals (!isNotebook) [
            "memory"
            "temperature"
          ]
          ++ lib.optionals isNotebook [
            "battery"
            "backlight"
          ]
          ++ [
            "custom/separator"
            "group/tray-cluster"
            "clock"
            "custom/power"
          ];

        "sway/language" = {
          format = "{} ";
          on-click = "${pkgs.sway}/bin/swaymsg input type:keyboard xkb_switch_layout next";
        };

        "sway/scratchpad" = {
          format = "{icon} {count}";
          show-empty = false;
          format-icons = ["" ""];
          on-click = "${pkgs.sway}/bin/swaymsg 'scratchpad show'";
          tooltip = true;
          tooltip-format = "{app} = {title}";
        };

        "custom/scratchpad" = {
          return-type = "json";
          exec = "${config.xdg.configHome}/waybar/scratchpad-status.sh";
          on-click = "${config.xdg.configHome}/waybar/scratchpad-toggle.sh";
          # Event-driven via niri-window-watcher.service; no polling needed
          interval = "once";
          signal = 12;
          format = "{text}";
          escape = true;
        };

        "custom/ncspot" = {
          return-type = "json";
          exec = ''echo '{"text":"\uf1bc","tooltip":"Open ncspot"}' '';
          interval = "once";
          on-click = "${config.xdg.configHome}/waybar/ncspot-toggle.sh";
          format = "{text}";
        };

        # Collapse ncspot + tray behind a single handle (browser-overflow
        # style). The anchor (custom/tray-handle) stays put; hovering it
        # reveals the rest, expanding leftward so the clock doesn't shift.
        "group/tray-cluster" = {
          orientation = "inherit";
          drawer = {
            transition-duration = 300;
            children-class = "tray-cluster-item";
            transition-left-to-right = false;
            click-to-reveal = true;
          };
          modules = ["custom/tray-handle" "custom/ncspot" "tray"];
        };

        "custom/tray-handle" = {
          format = "";
          tooltip = false;
        };

        # Collapse the left-side toggles (screenrec, idle, dnd, rotation) behind
        # a chevron handle — same drawer mechanic as the tray cluster, revealing
        # leftward so the rest of the right section never shifts.
        "group/toggles-cluster" = {
          orientation = "inherit";
          drawer = {
            transition-duration = 300;
            children-class = "toggles-cluster-item";
            transition-left-to-right = false;
            click-to-reveal = true;
          };
          modules =
            ["custom/toggles-handle" "custom/screenrec" "idle_inhibitor" "custom/dnd"]
            ++ lib.optionals isNotebook ["custom/rotation"];
        };

        "custom/toggles-handle" = {
          format = "";
          tooltip = false;
        };

        "custom/separator" = {
          format = "|";
        };

        clock = {
          interval = 60;
          format = "{:%e %b %Y %H:%M}";
          tooltip = true;
          tooltip-format = "<big>{:%B %Y}</big>\n<tt>{calendar}</tt>";
          on-click = dropkittenCmd tui.calendar;
        };

        "custom/dnd" = {
          return-type = "json";
          exec = "${config.xdg.configHome}/waybar/dnd-status.sh";
          on-click = "${config.xdg.configHome}/waybar/dnd-toggle.sh";
          interval = 30;
          signal = 11;
          format = "{text}";
          escape = true;
        };

        cpu = {
          # Bypass dropkitten so niri's btop_monitor window-rule controls sizing
          # (btop needs at least 80x24, dropkitten's fractional sizing came up short).
          on-click = "${config.terminal.bin} ${config.terminal.appIdFlag} btop_monitor ${config.terminal.execFlag} ${pkgs.btop}/bin/btop";
          format = "{usage}% ";
          tooltip = false;
        };

        "custom/menu" = {
          format = "";
          on-click = "${pkgs.rofi}/bin/rofi -show drun";
          tooltip = false;
        };

        "custom/power" = {
          format = "";
          on-click = "${config.xdg.configHome}/rofi/powermenu/powermenu.sh";
          tooltip = false;
        };

        memory = {format = "{}% ";};

        "custom/mpris" = {
          return-type = "json";
          exec = "${pkgs.waybar-mpris}/bin/waybar-mpris --order 'SYMBOL:PLAYER' --separator '' --autofocus --pause '' --play '' | ${pkgs.sd}/bin/sd '[Cc]hromium|chrome' 'Brave'";
          on-click = "${pkgs.waybar-mpris}/bin/waybar-mpris --send toggle";
          on-click-right = "${pkgs.waybar-mpris}/bin/waybar-mpris --send player-next";
          escape = true;
        };

        "custom/vpn" = {
          return-type = "json";
          exec = "${config.xdg.configHome}/waybar/vpn-status.sh";
          on-click = "${config.xdg.configHome}/waybar/vpn-picker.sh";
          on-click-right = "${config.xdg.configHome}/waybar/vpn-disconnect-all.sh";
          interval = 15;
          signal = 8;
          format = "{icon}{text}";
          format-icons = {
            connected = "󰖂";
            disconnected = "󰖂";
          };
          escape = true;
        };

        "custom/rotation" = {
          return-type = "json";
          exec = "${config.xdg.configHome}/waybar/rotation-status.sh";
          on-click = "${config.xdg.configHome}/waybar/rotation-toggle.sh";
          interval = 3;
          signal = 9;
          format = "{icon}";
          format-icons = {
            enabled = "";
            disabled = "";
          };
          escape = true;
        };

        bluetooth = {
          format = "󰂯 on";
          format-off = "󰂲 off";
          format-disabled = "󰂲 off";
          format-connected = "󰂱 {device_alias}";
          format-connected-battery = "󰂱 {device_alias} {device_battery_percentage}%";
          tooltip-format-connected = "{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
          tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_battery_percentage}%";
          on-click = dropkittenCmd tui.bluetooth;
          # Detect power state via D-Bus, not `bluetoothctl show`: BlueZ 5.86's
          # one-shot `show` exits before its object cache populates and prints
          # nothing, so the old grep never matched and only ever powered on.
          on-click-right = "sh -c 'if ${pkgs.systemd}/bin/busctl --system get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered | grep -q true; then ${pkgs.bluez}/bin/bluetoothctl power off; else ${pkgs.bluez}/bin/bluetoothctl power on; fi'";
        };

        network = {
          interval = 5;
          format-wifi = "{icon}";
          format-ethernet =
            if isNotebook
            then ""
            else "{ifname} ";
          format-disconnected = "󰖪";
          format-disabled = "󰀝";
          format-icons = [
            "󰤯"
            "󰤟"
            "󰤢"
            "󰤥"
            "󰤨"
          ];
          tooltip-format = "{icon} {ifname}: {ipaddr}";
          tooltip-format-ethernet = "{icon} {ifname}: {ipaddr}";
          tooltip-format-wifi = "{icon} {ifname} ({essid}): {ipaddr}";
          tooltip-format-disconnected = "{icon} disconnected";
          tooltip-format-disabled = "{icon} disabled";
          on-click = dropkittenCmd tui.wifi;
        };

        pulseaudio = {
          on-click = dropkittenCmd tui.audio;
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-icons = {
            car = "";
            default = ["" "" ""];
            handsfree = " ";
            headphones = " ";
            headset = " ";
            phone = "";
            portable = "";
          };
          format-muted = " {format_source}";
          format-source = " ";
          format-source-muted = " ";
        };

        "custom/screenrec" = {
          exec = "${config.xdg.configHome}/waybar/screenrec-status.sh";
          on-click = "${config.xdg.configHome}/waybar/screenrec-toggle.sh";
          return-type = "json";
          # Toggle script signals immediately on click; 30s is a safety net
          # for the rare case where wl-screenrec exits on its own
          interval = 30;
          signal = 10;
          format = "{}";
        };

        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "";
            deactivated = "";
          };
        };

        "sway/mode" = {format = ''<span style="italic">{}</span>'';};

        battery = {
          interval = 30;
          states = {
            warning = 30;
            critical = 15;
          };
          format-charging = "{capacity}% 󰂄";
          format = "{capacity}% {icon}";
          format-icons = ["󱃍" "󰁺" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
        };

        temperature = {
          critical-threshold = 80;
          format = "{temperatureC}°C {icon}";
          format-icons = "";
        };
        backlight = {
          format = "{percent}% {icon}";
          format-icons = ["󰃞" "󰃟" "󰃠"];
          on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl set +50";
          on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl set 50-";
        };
      }
    ];
  };
}
