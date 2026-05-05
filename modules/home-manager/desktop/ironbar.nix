{
  dropkittenPkg,
  pkgs,
  config,
  lib,
  isNotebook,
  ...
}: let
  dropkitten_size = {
    width = "0.35";
    height = "0.45";
  };

  dropkittenCmd = cmd:
    "${dropkittenPkg}/bin/dropkitten -t ${config.terminal.emulator} -W ${dropkitten_size.width} -H ${dropkitten_size.height} $(if [ -n \"$SWAYSOCK\" ]; then echo '-y 35'; fi) -- ${cmd}";

  tui = {
    bluetooth = "${pkgs.bluetuith}/bin/bluetuith";
    wifi = "${pkgs.bash}/bin/bash -c 'NEWT_COLORS=\"root=white,black:window=white,black:border=blue,black:listbox=white,black:actlistbox=black,blue:label=white,black:title=brightblue,black:button=white,black:actbutton=black,blue:compactbutton=white,black:checkbox=white,black:actcheckbox=black,blue:entry=white,black:textbox=white,black\" ${pkgs.networkmanager}/bin/nmtui connect'";
    audio = "${pkgs.wiremix}/bin/wiremix";
    calendar = "${pkgs.calcurse}/bin/calcurse";
  };
in {
  # PoC ironbar config — Rust/GTK4 alternative to waybar.
  #
  # To test alongside waybar:
  #   1. Add `./ironbar.nix` to the imports list in ./default.nix
  #   2. Rebuild: `sudo nixos-rebuild switch --flake .#intelNuc`
  #   3. The ironbar systemd user unit will start automatically.
  #      If you want to stop waybar while testing:
  #        systemctl --user stop waybar
  #        systemctl --user start ironbar    (already started by HM)
  #   4. To revert: remove the import line, rebuild.
  #
  # Native niri workspace support requires ironbar 0.16+, which is what
  # github:JakeStanger/ironbar tracks on master.

  # Status scripts shared with waybar where possible. New ones live under
  # ~/.config/ironbar/scripts/ to keep the bar's namespace tidy.
  xdg.configFile = {
    "ironbar/scripts/bluetooth-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        if ! ${pkgs.bluez}/bin/bluetoothctl show 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "Powered: yes"; then
          echo "󰂲 off"
          exit 0
        fi
        device=$(${pkgs.bluez}/bin/bluetoothctl devices Connected 2>/dev/null | ${pkgs.coreutils}/bin/head -1 | ${pkgs.coreutils}/bin/cut -d' ' -f3-)
        if [ -n "$device" ]; then
          echo "󰂱 $device"
        else
          echo "󰂯 on"
        fi
      '';
    };

    "ironbar/scripts/network-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        nmcli=${pkgs.networkmanager}/bin/nmcli
        state=$($nmcli -t -f STATE general)
        if [ "$state" != "connected" ]; then
          echo "󰖪 off"
          exit 0
        fi
        line=$($nmcli -t -f NAME,TYPE,DEVICE c show --active | ${pkgs.gnugrep}/bin/grep -v ':loopback:' | ${pkgs.coreutils}/bin/head -1)
        name=$(echo "$line" | ${pkgs.coreutils}/bin/cut -d: -f1)
        type=$(echo "$line" | ${pkgs.coreutils}/bin/cut -d: -f2)
        if [ "$type" = "802-11-wireless" ]; then
          signal=$($nmcli -t -f IN-USE,SIGNAL d wifi | ${pkgs.gnugrep}/bin/grep "^\*" | ${pkgs.coreutils}/bin/cut -d: -f2)
          icon="󰤨"
          [ -n "$signal" ] && {
            if   [ "$signal" -ge 80 ]; then icon="󰤨"
            elif [ "$signal" -ge 60 ]; then icon="󰤥"
            elif [ "$signal" -ge 40 ]; then icon="󰤢"
            elif [ "$signal" -ge 20 ]; then icon="󰤟"
            else icon="󰤯"
            fi
          }
          echo "$icon $name"
        else
          echo "󰈀 $name"
        fi
      '';
    };
  };

  programs.ironbar = {
    enable = true;

    # systemd user unit (matches the pattern waybar uses)
    systemd = true;

    config = {
      position = "top";
      height = 30;
      anchor_to_edges = true;

      # ── Left ─────────────────────────────────────────────────────────────
      start = [
        # App launcher button (mirrors custom/menu in waybar)
        {
          type = "custom";
          class = "menu";
          bar = [
            {
              type = "button";
              label = "";
              on_click = "!${pkgs.rofi}/bin/rofi -show drun";
            }
          ];
        }

        # Niri workspaces — ironbar auto-detects via $NIRI_SOCKET
        {
          type = "workspaces";
          all_monitors = false;
        }

        # Scratchpad toggle — reuses waybar's existing toggle script
        {
          type = "custom";
          class = "scratchpad";
          bar = [
            {
              type = "button";
              label = "";
              on_click = "!${config.xdg.configHome}/waybar/scratchpad-toggle.sh";
            }
          ];
        }
      ];

      # ── Center ───────────────────────────────────────────────────────────
      center = [
        {
          type = "clock";
          format = "%e %b %Y  %H:%M";
          format_popup = "%A, %e %B %Y";
          on_click_right = "!${dropkittenCmd tui.calendar}";
        }
      ];

      # ── Right ────────────────────────────────────────────────────────────
      end =
        [
          # System tray
          {
            type = "tray";
            icon_size = 14;
            direction = "right_to_left";
          }

          # MPRIS music — replaces waybar-mpris + sd pipe entirely.
          # ironbar speaks MPRIS natively, so no daemon needed.
          {
            type = "music";
            player_type = "mpris";
            show_status_icon = true;
            truncate = "end";
            truncate_len = 30;
            format = "{title} - {artist}";
            on_click_middle = "playerctl play-pause";
          }

          # Bluetooth — script status, click for bluetuith via dropkitten
          {
            type = "script";
            class = "bluetooth";
            cmd = "${config.xdg.configHome}/ironbar/scripts/bluetooth-status.sh";
            mode = "poll";
            interval = 5000;
            on_click_left = "!${dropkittenCmd tui.bluetooth}";
            on_click_right = "!sh -c 'if ${pkgs.bluez}/bin/bluetoothctl show | grep -q \"Powered: yes\"; then ${pkgs.bluez}/bin/bluetoothctl power off; else ${pkgs.bluez}/bin/bluetoothctl power on; fi'";
          }

          # Network — script status, click for nmtui via dropkitten
          {
            type = "script";
            class = "network";
            cmd = "${config.xdg.configHome}/ironbar/scripts/network-status.sh";
            mode = "poll";
            interval = 5000;
            on_click_left = "!${dropkittenCmd tui.wifi}";
          }

          # Volume — native popup on left-click, wiremix on right-click
          {
            type = "volume";
            format = "{percentage}% {icon}";
            max_volume = 100;
            format_icons = {
              volume_high = "";
              volume_medium = "";
              volume_low = "";
              muted = "";
            };
            on_click_right = "!${dropkittenCmd tui.audio}";
          }

          # CPU + memory + temperature snapshot
          {
            type = "sys_info";
            interval = {
              memory = 5;
              cpu = 5;
              temps = 10;
              disks = 60;
              networks = 30;
            };
            format = [
              " {cpu_percent}%"
              " {memory_used} / {memory_total} GiB"
              " {temp_c:k10temp}°C"
            ];
          }

          # VPN status (reuses your existing waybar script)
          {
            type = "script";
            cmd = "${config.xdg.configHome}/waybar/vpn-status.sh";
            mode = "watch";
            interval = 15;
          }
        ]
        ++ lib.optionals isNotebook [
          # Battery (notebook only)
          {
            type = "upower";
            format = "{percentage}% {icon}";
          }
        ]
        ++ [
          # ncspot opener (mirrors waybar's custom/ncspot button)
          {
            type = "custom";
            class = "ncspot";
            bar = [
              {
                type = "button";
                label = "";
                on_click = "!${config.xdg.configHome}/waybar/ncspot-toggle.sh";
              }
            ];
          }

          # Power menu
          {
            type = "custom";
            class = "power";
            bar = [
              {
                type = "button";
                label = "";
                on_click = "!${config.xdg.configHome}/rofi/powermenu/powermenu.sh";
              }
            ];
          }
        ];
    };

    # ── Theme ──────────────────────────────────────────────────────────────
    # Mirrors waybar/style.css: transparent bar, 15px pill widgets, brown
    # accent (@base0FE6) on clock/menu/power/focused workspace, dark-alpha
    # container (@base00E6) behind the workspace strip.
    style = with config.scheme; ''
      @define-color base00 #${base00};
      @define-color base01 #${base01};
      @define-color base02 #${base02};
      @define-color base03 #${base03};
      @define-color base04 #${base04};
      @define-color base05 #${base05};
      @define-color base06 #${base06};
      @define-color base08 #${base08};
      @define-color base0A #${base0A};
      @define-color base0B #${base0B};
      @define-color base0D #${base0D};
      @define-color base0E #${base0E};
      @define-color base00E6 rgba(30, 30, 30, 0.9);
      @define-color base0FE6 rgba(138, 129, 119, 0.9);

      /* Kill GTK theme defaults that bleed through */
      .background,
      .background *,
      window,
      box,
      .container {
        background-color: transparent;
        border: none;
        box-shadow: none;
        text-shadow: none;
      }

      /* Font + base text color, applied narrowly */
      label,
      button {
        color: @base05;
        font-family: "Symbols Nerd Font Mono", "JetBrainsMono Nerd Font Mono";
        font-size: 14px;
        min-height: 0;
        padding: 0;
      }

      /* Bar root — fully transparent */
      #bar {
        background: transparent;
        min-height: 28px;
      }

      /* Force every nested container to take only the height it needs */
      box,
      .container,
      .widget {
        min-height: 0;
      }

      /* Buttons everywhere (custom-module buttons): no GTK chrome */
      button {
        background: transparent;
        border: none;
        box-shadow: none;
        padding: 0 4px;
      }

      /* Plain widgets — flat on the transparent bar */
      .tray,
      .music,
      .volume,
      .sys-info,
      .upower,
      .bluetooth,
      .network,
      .ncspot,
      .script {
        padding: 0 5px;
        margin: 0 5px;
      }

      /* Accent pill widgets */
      .clock,
      .menu,
      .power,
      .scratchpad {
        background-color: @base0FE6;
        color: @base05;
        border-radius: 15px;
        padding: 0 10px;
        margin: 0 5px;
      }

      /* ncspot tint to match waybar's #custom-ncspot */
      .ncspot button {
        color: @base0B;
      }

      /* Workspaces strip — dark container, brown-accent on focused item */
      .workspaces {
        background-color: @base00E6;
        border-radius: 15px;
        padding: 0 4px;
        margin: 0 5px;
      }
      .workspaces .item {
        background: transparent;
        color: @base05;
        border-radius: 15px;
        padding: 0 10px;
        margin: 2px 2px;
        min-height: 0;
      }
      .workspaces .item.focused {
        background-color: @base0FE6;
        color: @base05;
      }
      .workspaces .item.urgent {
        color: @base08;
      }

      /* Music gets the ncspot-green accent */
      .music {
        color: @base0B;
      }

      /* Focused window title — quiet */
      .focused {
        color: @base05;
      }

      /* Battery state colors */
      .upower.warning {
        color: @base0A;
      }
      .upower.critical {
        color: @base08;
        animation: blink-critical 0.5s linear infinite alternate;
      }

      @keyframes blink-critical {
        0%   { color: @base05; }
        100% { color: @base08; }
      }
    '';
  };
}
