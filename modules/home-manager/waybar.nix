{
  inputs,
  config,
  pkgs,
  isNotebook,
  lib,
  ...
}: let
  dropkittenPkg = inputs.dropkitten.packages.${pkgs.stdenv.hostPlatform.system}.dropkitten;

  dropkitten_size = {
    width = "0.3";
    height = "0.4";
    yshift = "35";
  };

  dropkitten_command = "${dropkittenPkg}/bin/dropkitten -W ${dropkitten_size.width} -H ${dropkitten_size.height} -y ${dropkitten_size.yshift} --";

  # nmtui color scheme matching kitty theme
  nmtui_colors = "root=white,black:window=white,black:border=blue,black:listbox=white,black:actlistbox=black,blue:label=white,black:title=brightblue,black:button=white,black:actbutton=black,blue:compactbutton=white,black:checkbox=white,black:actcheckbox=black,blue:entry=white,black:textbox=white,black";
in {
  home.packages = with pkgs; [
    waybar-mpris
    calcurse
    kitty
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

    "waybar/vpn-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        # Check if TU Wien VPN is active
        if ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
            echo '{"text":" TU","alt":"connected","tooltip":"TU Wien VPN Connected","class":"connected"}'
            exit 0
        fi

        # Check if any PIA VPN is active
        ACTIVE_VPN=$(${pkgs.systemd}/bin/systemctl list-units --state=active --no-pager "openvpn-*" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP 'openvpn-\K[^.]+' | ${pkgs.coreutils}/bin/head -1)

        if [ -n "$ACTIVE_VPN" ]; then
            # PIA VPN is connected - format region name for display
            REGION_DISPLAY=$(echo "$ACTIVE_VPN" | ${pkgs.gnused}/bin/sed 's/-/ /g' | ${pkgs.gawk}/bin/awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
            # Map region names to proper ISO country codes
            case "$ACTIVE_VPN" in
                austria) SHORT="AT" ;;
                australia) SHORT="AU" ;;
                *) SHORT=$(echo "$ACTIVE_VPN" | ${pkgs.coreutils}/bin/cut -c1-2 | ${pkgs.coreutils}/bin/tr '[:lower:]' '[:upper:]') ;;
            esac
            echo "{\"text\":\" $SHORT\",\"alt\":\"connected\",\"tooltip\":\"PIA $REGION_DISPLAY Connected\",\"class\":\"connected\"}"
        else
            # No VPN is connected
            echo '{"text":" off","alt":"disconnected","tooltip":"Click to toggle last VPN, right-click to choose","class":"disconnected"}'
        fi
      '';
    };

    "waybar/vpn-toggle.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        # File to store last used VPN
        LAST_VPN_FILE="$HOME/.cache/last-vpn-region"
        DEFAULT_VPN="austria"

        # Check if TU Wien VPN is active
        if ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
            # TU Wien VPN is connected, disconnect it
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop openconnect-tuwien.service
            ${pkgs.libnotify}/bin/notify-send "VPN" "Disconnected from TU Wien VPN" -i network-vpn-disconnected
            ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
            exit 0
        fi

        # Check if any PIA VPN is currently active
        ACTIVE_PIA=$(${pkgs.systemd}/bin/systemctl list-units --state=active --no-pager "openvpn-*" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP 'openvpn-\K[^.]+' | ${pkgs.coreutils}/bin/head -1)

        if [ -n "$ACTIVE_PIA" ]; then
            # PIA VPN is connected, disconnect it
            REGION_NAME=$(echo "$ACTIVE_PIA" | ${pkgs.gnused}/bin/sed 's/-/ /g' | ${pkgs.gawk}/bin/awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
            /run/wrappers/bin/pkexec /run/current-system/sw/bin/pia stop "$ACTIVE_PIA"
            ${pkgs.libnotify}/bin/notify-send "VPN" "Disconnected from PIA $REGION_NAME" -i network-vpn-disconnected
            ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
            exit 0
        fi

        # No VPN is connected, connect to last used VPN
        LAST_VPN="$DEFAULT_VPN"
        if [ -f "$LAST_VPN_FILE" ]; then
            LAST_VPN=$(${pkgs.coreutils}/bin/cat "$LAST_VPN_FILE")
        fi

        # Check if last VPN was TU Wien
        if [ "$LAST_VPN" = "tuwien" ]; then
            ${pkgs.libnotify}/bin/notify-send "VPN" "Connecting to TU Wien VPN..." -i network-vpn
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl start openconnect-tuwien.service

            # Check if connection was successful
            ${pkgs.coreutils}/bin/sleep 3
            if ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
                ${pkgs.libnotify}/bin/notify-send "VPN" "Connected to TU Wien VPN" -i network-vpn
            else
                ${pkgs.libnotify}/bin/notify-send "VPN" "Failed to connect to TU Wien VPN" -i dialog-error
            fi
            ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
        else
            # Connect to PIA region
            REGION_NAME=$(echo "$LAST_VPN" | ${pkgs.gnused}/bin/sed 's/-/ /g' | ${pkgs.gawk}/bin/awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
            ${pkgs.libnotify}/bin/notify-send "VPN" "Connecting to PIA $REGION_NAME..." -i network-vpn
            /run/wrappers/bin/pkexec /run/current-system/sw/bin/pia start "$LAST_VPN"

            # Check if connection was successful
            ${pkgs.coreutils}/bin/sleep 3
            if ${pkgs.systemd}/bin/systemctl is-active "openvpn-$LAST_VPN.service" >/dev/null 2>&1; then
                ${pkgs.libnotify}/bin/notify-send "VPN" "Connected to PIA $REGION_NAME" -i network-vpn
            else
                ${pkgs.libnotify}/bin/notify-send "VPN" "Failed to connect to PIA $REGION_NAME" -i dialog-error
            fi
            ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
        fi
      '';
    };

    "waybar/vpn-picker.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        # File to store last selected VPN
        LAST_VPN_FILE="$HOME/.cache/last-vpn-region"

        # Check if TU Wien VPN is active
        TUWIEN_ACTIVE=$(${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1 && echo "yes" || echo "no")

        # Check if any PIA VPN is active
        ACTIVE_PIA=$(${pkgs.systemd}/bin/systemctl list-units --state=active --no-pager "openvpn-*" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP 'openvpn-\K[^.]+' | ${pkgs.coreutils}/bin/head -1)

        # Get list of all available PIA regions
        PIA_REGIONS=$(${pkgs.findutils}/bin/find /etc/systemd/system/ -name 'openvpn-*.service' -exec ${pkgs.coreutils}/bin/basename {} .service \; 2>/dev/null | ${pkgs.gnused}/bin/sed 's/openvpn-//' | ${pkgs.coreutils}/bin/sort)

        # Build menu
        MENU=""

        # Add disconnect option if any VPN is active
        if [ "$TUWIEN_ACTIVE" = "yes" ]; then
            MENU="Disconnect from TU Wien VPN\n"
        elif [ -n "$ACTIVE_PIA" ]; then
            REGION_NAME=$(echo "$ACTIVE_PIA" | ${pkgs.gnused}/bin/sed 's/-/ /g' | ${pkgs.gawk}/bin/awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
            MENU="Disconnect from PIA $REGION_NAME\n"
        fi

        # Add university VPN option
        MENU="$MENU🎓 TU Wien VPN\n---\n"

        # Add PIA regions
        MENU="$MENU$PIA_REGIONS"

        # Show rofi menu and get selection
        SELECTED=$(echo -e "$MENU" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Select VPN" -theme-str 'window {width: 400px;} listview {lines: 15;}')

        # Exit if no selection
        if [ -z "$SELECTED" ]; then
            exit 0
        fi

        # Handle disconnect options
        if [[ "$SELECTED" == "Disconnect from TU Wien VPN" ]]; then
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop openconnect-tuwien.service
            ${pkgs.libnotify}/bin/notify-send "VPN" "Disconnected from TU Wien VPN" -i network-vpn-disconnected
            ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
            exit 0
        elif [[ "$SELECTED" == "Disconnect"* ]]; then
            /run/wrappers/bin/pkexec /run/current-system/sw/bin/pia stop "$ACTIVE_PIA"
            ${pkgs.libnotify}/bin/notify-send "VPN" "Disconnected from PIA" -i network-vpn-disconnected
            ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
            exit 0
        fi

        # Skip separator
        if [[ "$SELECTED" == "---" ]]; then
            exit 0
        fi

        # Disconnect any active VPN first
        if [ "$TUWIEN_ACTIVE" = "yes" ]; then
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop openconnect-tuwien.service 2>/dev/null
        fi
        if [ -n "$ACTIVE_PIA" ]; then
            /run/wrappers/bin/pkexec /run/current-system/sw/bin/pia stop "$ACTIVE_PIA" 2>/dev/null
        fi

        # Handle TU Wien VPN selection
        if [[ "$SELECTED" == "🎓 TU Wien VPN" ]]; then
            ${pkgs.libnotify}/bin/notify-send "VPN" "Connecting to TU Wien VPN..." -i network-vpn
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl start openconnect-tuwien.service

            # Check if connection was successful
            ${pkgs.coreutils}/bin/sleep 3
            if ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
                ${pkgs.libnotify}/bin/notify-send "VPN" "Connected to TU Wien VPN" -i network-vpn
                echo "tuwien" > "$LAST_VPN_FILE"
            else
                ${pkgs.libnotify}/bin/notify-send "VPN" "Failed to connect to TU Wien VPN" -i dialog-error
            fi
            exit 0
        fi

        # Handle PIA VPN selection
        REGION_NAME=$(echo "$SELECTED" | ${pkgs.gnused}/bin/sed 's/-/ /g' | ${pkgs.gawk}/bin/awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
        ${pkgs.libnotify}/bin/notify-send "VPN" "Connecting to PIA $REGION_NAME..." -i network-vpn
        /run/wrappers/bin/pkexec /run/current-system/sw/bin/pia start "$SELECTED"

        # Check if connection was successful
        ${pkgs.coreutils}/bin/sleep 3
        if ${pkgs.systemd}/bin/systemctl is-active "openvpn-$SELECTED.service" >/dev/null 2>&1; then
            ${pkgs.libnotify}/bin/notify-send "VPN" "Connected to PIA $REGION_NAME" -i network-vpn
            echo "$SELECTED" > "$LAST_VPN_FILE"
        else
            ${pkgs.libnotify}/bin/notify-send "VPN" "Failed to connect to PIA $REGION_NAME" -i dialog-error
        fi
      '';
    };
  };

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      target = "sway-session.target";
    };
    style = "${./waybar/style.css}";
    settings = [
      {
        height = 30;
        layer = "top";
        position = "top";
        tray = {
          spacing = 10;
          icon-size = 14;
        };
        modules-left = ["custom/menu" "sway/workspaces" "sway/scratchpad" "sway/mode"];
        modules-right =
          [
            "idle_inhibitor"
          ]
          ++ lib.optionals isNotebook [
            "custom/rotation"
          ]
          ++ [
            "bluetooth"
            "pulseaudio"
            "custom/mpris"
            "custom/separator"
            "network"
            "custom/vpn"
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

        "custom/separator" = {
          format = "|";
        };

        clock = {
          interval = 60;
          format = "{:%e %b %Y %H:%M}";
          tooltip = true;
          tooltip-format = "<big>{:%B %Y}</big>\n<tt>{calendar}</tt>";
          on-click = "${dropkitten_command} ${pkgs.calcurse}/bin/calcurse";
        };

        cpu = {
          on-click = "${pkgs.kitty}/bin/kitty --app-id floating_shell -e ${pkgs.btop}/bin/btop";
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
          on-click = "${pkgs.sway}/bin/swaymsg exec ${config.xdg.configHome}/rofi/powermenu/powermenu.sh";
          tooltip = false;
        };

        memory = {format = "{}% ";};

        "custom/mpris" = {
          return-type = "json";
          exec = "${pkgs.waybar-mpris}/bin/waybar-mpris --order 'SYMBOL:PLAYER' --separator '' --autofocus --pause '' --play ''";
          on-click = "${pkgs.waybar-mpris}/bin/waybar-mpris --send toggle";
          on-click-right = "${pkgs.waybar-mpris}/bin/waybar-mpris --send player-next";
          escape = true;
        };

        "custom/vpn" = {
          return-type = "json";
          exec = "${config.xdg.configHome}/waybar/vpn-status.sh";
          on-click = "${config.xdg.configHome}/waybar/vpn-toggle.sh";
          on-click-right = "${config.xdg.configHome}/waybar/vpn-picker.sh";
          interval = 3;
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
          format = "󰂯";
          format-disabled = "󰂲 off";
          on-click = "${dropkitten_command} ${pkgs.bluetuith}/bin/bluetuith";
          on-click-right = "${pkgs.util-linux}/bin/rfkill toggle bluetooth";
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
          on-click = "${dropkitten_command} ${pkgs.bash}/bin/bash -c 'NEWT_COLORS=\"${nmtui_colors}\" ${pkgs.networkmanager}/bin/nmtui connect'";
        };

        pulseaudio = {
          on-click = "${dropkitten_command} ${pkgs.pulsemixer}/bin/pulsemixer";
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
