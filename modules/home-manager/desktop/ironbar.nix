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

  dropkittenCmd = cmd: "${dropkittenPkg}/bin/dropkitten -t ${config.terminal.emulator} -W ${dropkitten_size.width} -H ${dropkitten_size.height} $(if [ -n \"$SWAYSOCK\" ]; then echo '-y 35'; fi) -- ${cmd}";

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
        # Match waybar's network module: icon only (no SSID/ifname).
        nmcli=${pkgs.networkmanager}/bin/nmcli
        state=$($nmcli -t -f STATE general)
        if [ "$state" != "connected" ]; then
          echo "󰖪"
          exit 0
        fi
        type=$($nmcli -t -f NAME,TYPE,DEVICE c show --active | ${pkgs.gnugrep}/bin/grep -v ':loopback:' | ${pkgs.coreutils}/bin/head -1 | ${pkgs.coreutils}/bin/cut -d: -f2)
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
          echo "$icon"
        else
          echo "󰈀"
        fi
      '';
    };

    # Plain-text variants of waybar status scripts for ironbar's poll-mode
    # script widget (which displays stdout verbatim, no JSON parsing).
    #
    # Icons are emitted via `printf '\xXX\xXX\xXX'` (UTF-8 byte escapes) so
    # the Nerd Font private-use-area codepoints survive any text editing.
    "ironbar/scripts/dnd-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        # Bell-slash (U+F1F6) when DND on; bell (U+F0F3) when off.
        if ${pkgs.mako}/bin/makoctl mode | ${pkgs.ripgrep}/bin/rg -q "do-not-disturb"; then
          printf '\xef\x87\xb6\n'
        else
          printf '\xef\x83\xb3\n'
        fi
      '';
    };

    "ironbar/scripts/screenrec-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        if ${pkgs.procps}/bin/pgrep -x wl-screenrec >/dev/null 2>&1; then
          echo "REC"
        else
          echo ""
        fi
      '';
    };

    "ironbar/scripts/rotation-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        # rotate (U+F2F1) when enabled, lock-rotate (U+F109) when disabled.
        if [ -f "$HOME/.cache/rotation-state" ]; then
          printf '\xef\x84\x89\n'
        else
          printf '\xef\x8b\xb1\n'
        fi
      '';
    };

    "ironbar/scripts/vpn-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        # Shield/VPN icon (U+F0582, Material Design — 4 UTF-8 bytes)
        ICON=$(printf '\xf3\xb0\x96\x82')
        ACTIVE=()
        ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1 && ACTIVE+=("TAIL")
        ${pkgs.systemd}/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1 && ACTIVE+=("PIA")
        ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1 && ACTIVE+=("TU")
        if [ ''${#ACTIVE[@]} -gt 0 ]; then
          LABEL=$(IFS=/; echo "''${ACTIVE[*]}")
          echo "$ICON $LABEL"
        else
          echo "$ICON off"
        fi
      '';
    };

    "ironbar/scripts/idle-inhibit-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        # eye (U+F06E) when active, eye-slash (U+F070) when off
        if [ -f "$HOME/.cache/idle-inhibited" ]; then
          printf '\xef\x81\xae\n'
        else
          printf '\xef\x81\xb0\n'
        fi
      '';
    };

    "ironbar/scripts/idle-inhibit-toggle.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        STATE_FILE="$HOME/.cache/idle-inhibited"
        PID_FILE="$HOME/.cache/idle-inhibited.pid"
        if [ -f "$STATE_FILE" ]; then
          [ -f "$PID_FILE" ] && ${pkgs.coreutils}/bin/kill "$(${pkgs.coreutils}/bin/cat "$PID_FILE")" 2>/dev/null
          ${pkgs.coreutils}/bin/rm -f "$STATE_FILE" "$PID_FILE"
        else
          ${pkgs.systemd}/bin/systemd-inhibit --what=idle:sleep --who=ironbar --why="manual hold" ${pkgs.coreutils}/bin/sleep infinity &
          echo $! > "$PID_FILE"
          ${pkgs.coreutils}/bin/touch "$STATE_FILE"
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
      # Empty — waybar puts the clock on the right, so we do too.
      center = [];

      # ── Right ────────────────────────────────────────────────────────────
      # Mirrors waybar's modules-right ordering (modules/home-manager/desktop/waybar.nix:480).
      end =
        [
          # Screen recording status (only visible while recording)
          {
            type = "script";
            class = "screenrec";
            cmd = "${config.xdg.configHome}/ironbar/scripts/screenrec-status.sh";
            mode = "poll";
            interval = 5000;
            on_click_left = "!${config.xdg.configHome}/waybar/screenrec-toggle.sh";
          }

          # Idle inhibitor toggle
          {
            type = "custom";
            class = "idle_inhibitor";
            bar = [
              {
                type = "button";
                label = "{{2000:${config.xdg.configHome}/ironbar/scripts/idle-inhibit-status.sh}}";
                on_click = "!${config.xdg.configHome}/ironbar/scripts/idle-inhibit-toggle.sh";
              }
            ];
          }

          # Do-not-disturb toggle
          {
            type = "custom";
            class = "dnd";
            bar = [
              {
                type = "button";
                label = "{{2000:${config.xdg.configHome}/ironbar/scripts/dnd-status.sh}}";
                on_click = "!${config.xdg.configHome}/waybar/dnd-toggle.sh";
              }
            ];
          }
        ]
        ++ lib.optionals isNotebook [
          # Rotation toggle (notebook only)
          {
            type = "custom";
            class = "rotation";
            bar = [
              {
                type = "button";
                label = "{{3000:${config.xdg.configHome}/ironbar/scripts/rotation-status.sh}}";
                on_click = "!${config.xdg.configHome}/waybar/rotation-toggle.sh";
              }
            ];
          }
        ]
        ++ [
          { type = "label"; label = "|"; class = "separator"; }

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

          # MPRIS music — ironbar speaks MPRIS natively, no daemon needed.
          {
            type = "music";
            player_type = "mpris";
            show_status_icon = true;
            truncate = "end";
            truncate_len = 30;
            format = "{title} - {artist}";
            on_click_middle = "playerctl play-pause";
          }

          { type = "label"; label = "|"; class = "separator"; }

          # Network — script status, click for nmtui via dropkitten
          {
            type = "script";
            class = "network";
            cmd = "${config.xdg.configHome}/ironbar/scripts/network-status.sh";
            mode = "poll";
            interval = 5000;
            on_click_left = "!${dropkittenCmd tui.wifi}";
          }

          # VPN status — plain-text script
          {
            type = "script";
            class = "vpn";
            cmd = "${config.xdg.configHome}/ironbar/scripts/vpn-status.sh";
            mode = "poll";
            interval = 15000;
            on_click_left = "!${config.xdg.configHome}/waybar/vpn-picker.sh";
            on_click_right = "!${config.xdg.configHome}/waybar/vpn-disconnect-all.sh";
          }

          { type = "label"; label = "|"; class = "separator"; }

          # CPU + memory + temperature snapshot (desktop) or just CPU on notebook.
          # Waybar splits these into separate widgets; ironbar groups them into sys_info.
          {
            type = "sys_info";
            interval = {
              memory = 5;
              cpu = 5;
              temps = 10;
              disks = 60;
              networks = 30;
            };
            format =
              if isNotebook
              then [" {cpu_percent}%"]
              else [
                " {cpu_percent}%"
                " {memory_used} / {memory_total} GiB"
                " {temp_c:coretemp}°C"
              ];
          }
        ]
        ++ lib.optionals isNotebook [
          # Battery + backlight (notebook only)
          {
            type = "upower";
            format = "{percentage}% {icon}";
          }
        ]
        ++ [
          { type = "label"; label = "|"; class = "separator"; }

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

          # System tray
          {
            type = "tray";
            icon_size = 14;
            direction = "horizontal";
          }

          # Clock — on the right, matching waybar
          {
            type = "clock";
            format = "%e %b %Y  %H:%M";
            format_popup = "%A, %e %B %Y";
            on_click_right = "!${dropkittenCmd tui.calendar}";
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
    # Style lives in ./ironbar/style.css as a writable file (mkOutOfStoreSymlink).
    # Edits land instantly: ironbar watches style.css via inotify and re-applies
    # CSS without a process restart — no `home-manager switch` needed.
    #
    # If you change colors in modules/home-manager/theming/base16-scheme.nix,
    # update the @define-color block in style.css to match.
    style =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.config/nixos/modules/home-manager/desktop/ironbar/style.css";
  };
}
