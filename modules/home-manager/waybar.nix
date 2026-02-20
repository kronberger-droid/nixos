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
    width = "0.35";
    height = "0.45";
    yshift = "35";
  };

  dropkitten_command = "${dropkittenPkg}/bin/dropkitten -t ${config.terminal.emulator} -W ${dropkitten_size.width} -H ${dropkitten_size.height} -y ${dropkitten_size.yshift} --";

  # nmtui color scheme matching kitty theme
  nmtui_colors = "root=white,black:window=white,black:border=blue,black:listbox=white,black:actlistbox=black,blue:label=white,black:title=brightblue,black:button=white,black:actbutton=black,blue:compactbutton=white,black:checkbox=white,black:actcheckbox=black,blue:entry=white,black:textbox=white,black";

  tui = {
    bluetooth = "${pkgs.bluetui}/bin/bluetui";
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

    "waybar/vpn-status.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        # Check if TU Wien VPN is active
        if ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
            echo '{"text":" TU","alt":"connected","tooltip":"TU Wien VPN Connected","class":"connected"}'
            exit 0
        fi

        # Check if PIA VPN is active
        if ${pkgs.systemd}/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1; then
            echo '{"text":" PIA","alt":"connected","tooltip":"PIA VPN Connected","class":"connected"}'
            exit 0
        fi

        # No VPN is connected
        echo '{"text":" off","alt":"disconnected","tooltip":"Click to toggle, right-click to choose","class":"disconnected"}'
      '';
    };

    "waybar/vpn-toggle.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        # Check if TU Wien VPN is active
        if ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop openconnect-tuwien.service
            ${pkgs.libnotify}/bin/notify-send "VPN" "Disconnected from TU Wien VPN" -i network-vpn-disconnected
            ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
            exit 0
        fi

        # Check if PIA VPN is active
        if ${pkgs.systemd}/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1; then
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop pia-vpn.service
            ${pkgs.libnotify}/bin/notify-send "VPN" "Disconnected from PIA VPN" -i network-vpn-disconnected
            ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
            exit 0
        fi

        # No VPN is connected -- start PIA
        ${pkgs.libnotify}/bin/notify-send "VPN" "Connecting to PIA VPN..." -i network-vpn
        /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl start pia-vpn.service

        ${pkgs.coreutils}/bin/sleep 3
        if ${pkgs.systemd}/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1; then
            ${pkgs.libnotify}/bin/notify-send "VPN" "Connected to PIA VPN" -i network-vpn
        else
            ${pkgs.libnotify}/bin/notify-send "VPN" "Failed to connect to PIA VPN" -i dialog-error
        fi
        ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
      '';
    };

    "waybar/vpn-picker.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        # Check current VPN state
        TUWIEN_ACTIVE=$(${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1 && echo "yes" || echo "no")
        PIA_ACTIVE=$(${pkgs.systemd}/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1 && echo "yes" || echo "no")

        # Build menu
        MENU=""

        # Add disconnect option if any VPN is active
        if [ "$TUWIEN_ACTIVE" = "yes" ]; then
            MENU="Disconnect from TU Wien VPN\n"
        elif [ "$PIA_ACTIVE" = "yes" ]; then
            MENU="Disconnect from PIA VPN\n"
        fi

        MENU="''${MENU}TU Wien VPN\nPIA VPN"

        # Show rofi menu and get selection
        SELECTED=$(echo -e "$MENU" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Select VPN" -theme-str 'window {width: 400px;} listview {lines: 5;}')

        # Exit if no selection
        if [ -z "$SELECTED" ]; then
            exit 0
        fi

        # Handle disconnect
        if [[ "$SELECTED" == "Disconnect from TU Wien VPN" ]]; then
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop openconnect-tuwien.service
            ${pkgs.libnotify}/bin/notify-send "VPN" "Disconnected from TU Wien VPN" -i network-vpn-disconnected
            ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
            exit 0
        elif [[ "$SELECTED" == "Disconnect from PIA VPN" ]]; then
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop pia-vpn.service
            ${pkgs.libnotify}/bin/notify-send "VPN" "Disconnected from PIA VPN" -i network-vpn-disconnected
            ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
            exit 0
        fi

        # Disconnect any active VPN first
        if [ "$TUWIEN_ACTIVE" = "yes" ]; then
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop openconnect-tuwien.service 2>/dev/null
        fi
        if [ "$PIA_ACTIVE" = "yes" ]; then
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop pia-vpn.service 2>/dev/null
        fi

        # Connect to selected VPN
        if [[ "$SELECTED" == "TU Wien VPN" ]]; then
            ${pkgs.libnotify}/bin/notify-send "VPN" "Connecting to TU Wien VPN..." -i network-vpn
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl start openconnect-tuwien.service

            ${pkgs.coreutils}/bin/sleep 3
            if ${pkgs.systemd}/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
                ${pkgs.libnotify}/bin/notify-send "VPN" "Connected to TU Wien VPN" -i network-vpn
            else
                ${pkgs.libnotify}/bin/notify-send "VPN" "Failed to connect to TU Wien VPN" -i dialog-error
            fi
        elif [[ "$SELECTED" == "PIA VPN" ]]; then
            ${pkgs.libnotify}/bin/notify-send "VPN" "Connecting to PIA VPN..." -i network-vpn
            /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl start pia-vpn.service

            ${pkgs.coreutils}/bin/sleep 3
            if ${pkgs.systemd}/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1; then
                ${pkgs.libnotify}/bin/notify-send "VPN" "Connected to PIA VPN" -i network-vpn
            else
                ${pkgs.libnotify}/bin/notify-send "VPN" "Failed to connect to PIA VPN" -i dialog-error
            fi
        fi

        ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
      '';
    };
  };

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      target = "sway-session.target";
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
          on-click = "${dropkitten_command} ${tui.calendar}";
        };

        cpu = {
          on-click =
            if config.terminal.floatingAppId != null
            then "${config.terminal.bin} ${config.terminal.appIdFlag} ${config.terminal.floatingAppId} ${config.terminal.execFlag} ${tui.monitor}"
            else "${config.terminal.bin} ${config.terminal.execFlag} ${tui.monitor}";
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
          on-click = "${dropkitten_command} ${tui.bluetooth}";
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
          on-click = "${dropkitten_command} ${tui.wifi}";
        };

        pulseaudio = {
          on-click = "${dropkitten_command} ${tui.audio}";
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
