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

    "waybar/rotation-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        # Check if rotation is disabled (state file exists)
        if [ -f "$HOME/.cache/rotation-state" ]; then
            echo '{"icon":"disabled","alt":"disabled","tooltip":"Auto-rotation Disabled","class":"disabled"}'
        else
            echo '{"icon":"enabled","alt":"enabled","tooltip":"Auto-rotation Enabled","class":"enabled"}'
        fi
      '';
    };

    "waybar/rotation-toggle.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        STATE_FILE="$HOME/.cache/rotation-state"

        # Toggle rotation state
        if [ -f "$STATE_FILE" ]; then
            # Enable rotation
            ${pkgs.coreutils}/bin/rm -f "$STATE_FILE"
            ${pkgs.rot8}/bin/rot8 &
            ${pkgs.libnotify}/bin/notify-send "Auto-rotation" "Screen auto-rotation enabled" -i display-brightness
        else
            # Disable rotation
            ${pkgs.coreutils}/bin/touch "$STATE_FILE"
            ${pkgs.procps}/bin/pkill rot8
            ${pkgs.libnotify}/bin/notify-send "Auto-rotation" "Screen auto-rotation disabled" -i display-brightness
        fi

        # Refresh waybar
        ${pkgs.procps}/bin/pkill -RTMIN+9 waybar 2>/dev/null || true
      '';
    };

    "waybar/screenrec-toggle.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        if ${pkgs.procps}/bin/pidof wl-screenrec >/dev/null 2>&1; then
          ${pkgs.procps}/bin/pkill wl-screenrec
          ${pkgs.libnotify}/bin/notify-send "Screen Recording" "Recording stopped"
        else
          GEOMETRY=$(${pkgs.slurp}/bin/slurp 2>/dev/null)
          if [ -z "$GEOMETRY" ]; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/mkdir -p "$HOME/Videos"
          FILENAME="$HOME/Videos/recording-$(${pkgs.coreutils}/bin/date +%Y-%m-%d-%H-%M-%S).mp4"
          ${pkgs.wl-screenrec}/bin/wl-screenrec -g "$GEOMETRY" -f "$FILENAME" &
          disown
          ${pkgs.libnotify}/bin/notify-send "Screen Recording" "Recording started: $(${pkgs.coreutils}/bin/basename "$FILENAME")"
        fi
        ${pkgs.procps}/bin/pkill -RTMIN+10 waybar 2>/dev/null || true
      '';
    };

    "waybar/screenrec-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        if ${pkgs.procps}/bin/pidof wl-screenrec >/dev/null 2>&1; then
          echo '{"text":"REC","class":"recording"}'
        else
          echo ""
        fi
      '';
    };

    "waybar/vpn-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        ACTIVE=()
        TOOLTIPS=()

        # Check Tailscale
        if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
            ACTIVE+=("TAIL")
            TOOLTIPS+=("Tailscale: Connected")
        fi

        # Check PIA VPN
        if ${pkgs.systemd}/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1; then
            ACTIVE+=("PIA")
            TOOLTIPS+=("PIA VPN: Connected")
        fi

        # Check TU Wien VPN
        if ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
            ACTIVE+=("TU")
            TOOLTIPS+=("TU Wien VPN: Connected")
        fi

        if [ ''${#ACTIVE[@]} -gt 0 ]; then
            LABEL=$(IFS=/; echo "''${ACTIVE[*]}")
            # Join tooltips with literal \n for waybar tooltip rendering
            TOOLTIP=""
            for i in "''${!TOOLTIPS[@]}"; do
                [ -n "$TOOLTIP" ] && TOOLTIP+="\\n"
                TOOLTIP+="''${TOOLTIPS[$i]}"
            done
            echo "{\"text\":\" $LABEL\",\"alt\":\"connected\",\"tooltip\":\"$TOOLTIP\",\"class\":\"connected\"}"
        else
            echo '{"text":" off","alt":"disconnected","tooltip":"No VPN active","class":"disconnected"}'
        fi
      '';
    };

    "waybar/vpn-disconnect-all.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        NOTIFY="${pkgs.libnotify}/bin/notify-send"
        ANY_ACTIVE=false

        # Disconnect Tailscale
        if ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
            ${pkgs.tailscale}/bin/tailscale down
            ANY_ACTIVE=true
        fi

        # Disconnect PIA
        if ${pkgs.systemd}/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1; then
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop pia-vpn.service
            ANY_ACTIVE=true
        fi

        # Disconnect TU Wien
        if ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop openconnect-tuwien.service
            ANY_ACTIVE=true
        fi

        if [ "$ANY_ACTIVE" = true ]; then
            $NOTIFY "VPN" "All VPNs disconnected" -i network-vpn-disconnected
        else
            $NOTIFY "VPN" "No VPNs were active" -i network-vpn-disconnected
        fi

        ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
      '';
    };

    "waybar/vpn-picker.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        NOTIFY="${pkgs.libnotify}/bin/notify-send"
        SIGNAL="${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true"
        SUDO="/run/wrappers/bin/sudo"
        SCTL="/run/current-system/sw/bin/systemctl"

        # Check current state of each VPN
        TAIL_ON=$(${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1 && echo "yes" || echo "no")
        PIA_ON=$(${pkgs.systemd}/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1 && echo "yes" || echo "no")
        TU_ON=$(${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1 && echo "yes" || echo "no")

        # Build menu with status indicators
        MENU=""
        [ "$TAIL_ON" = "yes" ] && MENU+="[ON]  Tailscale\n" || MENU+="[OFF] Tailscale\n"
        [ "$PIA_ON"  = "yes" ] && MENU+="[ON]  PIA VPN\n"   || MENU+="[OFF] PIA VPN\n"
        [ "$TU_ON"   = "yes" ] && MENU+="[ON]  TU Wien VPN" || MENU+="[OFF] TU Wien VPN"

        SELECTED=$(echo -e "$MENU" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "VPN" -theme-str 'window {width: 400px;} listview {lines: 3;}')

        [ -z "$SELECTED" ] && exit 0

        # Extract VPN name (strip "[ON]  " or "[OFF] " prefix)
        VPN_NAME=$(echo "$SELECTED" | ${pkgs.sd}/bin/sd '^\[O[NF]*\] *' '''')

        case "$VPN_NAME" in
            Tailscale)
                if [ "$TAIL_ON" = "yes" ]; then
                    ${pkgs.tailscale}/bin/tailscale down
                    $NOTIFY "VPN" "Tailscale disconnected" -i network-vpn-disconnected
                else
                    ${pkgs.tailscale}/bin/tailscale up
                    $NOTIFY "VPN" "Tailscale connected" -i network-vpn
                fi
                ;;
            "PIA VPN")
                if [ "$PIA_ON" = "yes" ]; then
                    $SUDO $SCTL stop pia-vpn.service
                    $NOTIFY "VPN" "PIA VPN disconnected" -i network-vpn-disconnected
                else
                    $NOTIFY "VPN" "Connecting to PIA VPN..." -i network-vpn
                    $SUDO $SCTL start pia-vpn.service
                    ${pkgs.coreutils}/bin/sleep 3
                    if ${pkgs.systemd}/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1; then
                        $NOTIFY "VPN" "PIA VPN connected" -i network-vpn
                    else
                        $NOTIFY "VPN" "Failed to connect to PIA VPN" -i dialog-error
                    fi
                fi
                ;;
            "TU Wien VPN")
                if [ "$TU_ON" = "yes" ]; then
                    $SUDO $SCTL stop openconnect-tuwien.service
                    $NOTIFY "VPN" "TU Wien VPN disconnected" -i network-vpn-disconnected
                else
                    $NOTIFY "VPN" "Connecting to TU Wien VPN..." -i network-vpn
                    $SUDO $SCTL start openconnect-tuwien.service
                    ${pkgs.coreutils}/bin/sleep 3
                    if ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
                        $NOTIFY "VPN" "TU Wien VPN connected" -i network-vpn
                    else
                        $NOTIFY "VPN" "Failed to connect to TU Wien VPN" -i dialog-error
                    fi
                fi
                ;;
        esac

        ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
      '';
    };

    "waybar/scratchpad-toggle.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        APP_ID="scratchpad"
        SESSION_NAME="scratchpad"
        JQ="${pkgs.jq}/bin/jq"

        window_exists() {
          niri msg -j windows | $JQ -e ".[] | select(.app_id == \"$APP_ID\")" >/dev/null 2>&1
        }

        # Wait until niri's window list matches expected state
        await_state() {
          local want="$1"
          for _ in $(seq 1 20); do
            if [ "$want" = "open" ] && window_exists; then return 0; fi
            if [ "$want" = "closed" ] && ! window_exists; then return 0; fi
            ${pkgs.coreutils}/bin/sleep 0.05
          done
        }

        WINDOW_JSON=$(niri msg -j windows)
        WINDOW_ID=$(echo "$WINDOW_JSON" | $JQ -r '.[] | select(.app_id == "'"$APP_ID"'") | .id // empty')

        if [ -n "$WINDOW_ID" ]; then
          FOCUSED_APP=$(niri msg -j focused-window | $JQ -r '.app_id // empty')
          if [ "$FOCUSED_APP" = "$APP_ID" ]; then
            niri msg action close-window --id "$WINDOW_ID"
            await_state "closed"
          else
            niri msg action focus-window --id "$WINDOW_ID"
          fi
        else
          ${config.terminal.bin} ${config.terminal.appIdFlag} "$APP_ID" ${config.terminal.execFlag} ${pkgs.zellij}/bin/zellij attach "$SESSION_NAME" --create
          await_state "open"
        fi

        ${pkgs.procps}/bin/pkill -RTMIN+12 waybar 2>/dev/null || true
      '';
    };

    "waybar/scratchpad-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        if niri msg -j windows 2>/dev/null | ${pkgs.jq}/bin/jq -e '.[] | select(.app_id == "scratchpad")' >/dev/null 2>&1; then
          echo '{"text":"\uf489","alt":"open","tooltip":"Scratchpad open","class":"open"}'
        else
          echo '{"text":"\uf489","alt":"closed","tooltip":"Scratchpad closed","class":"closed"}'
        fi
      '';
    };

    "waybar/ncspot-toggle.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        APP_ID="ncspot_popup"
        SESSION_NAME="ncspot"
        JQ="${pkgs.jq}/bin/jq"

        window_exists() {
          niri msg -j windows | $JQ -e ".[] | select(.app_id == \"$APP_ID\")" >/dev/null 2>&1
        }

        await_state() {
          local want="$1"
          for _ in $(seq 1 20); do
            if [ "$want" = "open" ] && window_exists; then return 0; fi
            if [ "$want" = "closed" ] && ! window_exists; then return 0; fi
            ${pkgs.coreutils}/bin/sleep 0.05
          done
        }

        WINDOW_JSON=$(niri msg -j windows)
        WINDOW_ID=$(echo "$WINDOW_JSON" | $JQ -r '.[] | select(.app_id == "'"$APP_ID"'") | .id // empty')

        if [ -n "$WINDOW_ID" ]; then
          FOCUSED_APP=$(niri msg -j focused-window | $JQ -r '.app_id // empty')
          if [ "$FOCUSED_APP" = "$APP_ID" ]; then
            niri msg action close-window --id "$WINDOW_ID"
            await_state "closed"
          else
            niri msg action focus-window --id "$WINDOW_ID"
          fi
        else
          ${config.terminal.bin} ${config.terminal.appIdFlag} "$APP_ID" ${config.terminal.execFlag} ${pkgs.zellij}/bin/zellij -l ncspot attach "$SESSION_NAME" --create
          await_state "open"
        fi
      '';
    };

    "waybar/dnd-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        MODE=$(${pkgs.mako}/bin/makoctl mode)
        if echo "$MODE" | ${pkgs.ripgrep}/bin/rg -q "do-not-disturb"; then
            echo '{"text":"\uf1f6","alt":"on","tooltip":"Do Not Disturb: ON","class":"on"}'
        else
            echo '{"text":"\uf0f3","alt":"off","tooltip":"Do Not Disturb: OFF","class":"off"}'
        fi
      '';
    };

    "waybar/dnd-toggle.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        MODE=$(${pkgs.mako}/bin/makoctl mode)
        if echo "$MODE" | ${pkgs.ripgrep}/bin/rg -q "do-not-disturb"; then
            ${pkgs.mako}/bin/makoctl mode -r do-not-disturb
            ${pkgs.libnotify}/bin/notify-send "Do Not Disturb" "Notifications enabled" -i notification
        else
            ${pkgs.mako}/bin/makoctl mode -s do-not-disturb
        fi
        ${pkgs.procps}/bin/pkill -RTMIN+11 waybar 2>/dev/null || true
      '';
    };
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
            "custom/screenrec"
            "idle_inhibitor"
            "custom/dnd"
          ]
          ++ lib.optionals isNotebook [
            "custom/rotation"
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
            "custom/ncspot"
            "tray"
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
          interval = 2;
          signal = 12;
          format = "{text}";
          escape = true;
        };

        "custom/ncspot" = {
          return-type = "json";
          exec = ''echo '{"text":"\uf1bc","tooltip":"Open ncspot"}' '';
          interval = 0;
          on-click = "${config.xdg.configHome}/waybar/ncspot-toggle.sh";
          format = "{text}";
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
          on-click = dropkittenCmd tui.monitor;
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
          on-click-right = "sh -c 'if ${pkgs.bluez}/bin/bluetoothctl show | grep -q \"Powered: yes\"; then ${pkgs.bluez}/bin/bluetoothctl power off; else ${pkgs.bluez}/bin/bluetoothctl power on; fi'";
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
          format-source = "\ ";
          format-source-muted = "\ ";
        };

        "custom/screenrec" = {
          exec = "${config.xdg.configHome}/waybar/screenrec-status.sh";
          on-click = "${config.xdg.configHome}/waybar/screenrec-toggle.sh";
          return-type = "json";
          interval = 2;
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
