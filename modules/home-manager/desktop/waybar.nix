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

    "waybar/vpn-toggle.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        # Left-click opens the picker for independent VPN control
        exec ${config.xdg.configHome}/waybar/vpn-picker.sh
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
        tag_on="[ON] " tag_off="[OFF]"
        MENU=""
        [ "$TAIL_ON" = "yes" ] && MENU+="$tag_on Tailscale\n" || MENU+="$tag_off Tailscale\n"
        [ "$PIA_ON"  = "yes" ] && MENU+="$tag_on PIA VPN\n"    || MENU+="$tag_off PIA VPN\n"
        [ "$TU_ON"   = "yes" ] && MENU+="$tag_on TU Wien VPN"  || MENU+="$tag_off TU Wien VPN"

        SELECTED=$(echo -e "$MENU" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "VPN" -theme-str 'window {width: 400px;} listview {lines: 3;}')

        [ -z "$SELECTED" ] && exit 0

        # Extract VPN name (strip status prefix)
        VPN_NAME="''${SELECTED#*] }"

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
  };

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      target = "graphical-session.target";
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
        modules-left = ["custom/menu" "sway/workspaces" "niri/workspaces" "sway/scratchpad" "sway/mode"];
        modules-right =
          [
            "custom/screenrec"
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
          on-click = dropkittenCmd tui.calendar;
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
          format = "󰂯";
          format-disabled = "󰂲 off";
          on-click = dropkittenCmd tui.bluetooth;
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
