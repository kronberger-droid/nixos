{ pkgs, host, lib, ... }:

let
  isNotebook = host == "t480s";
in

{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      * {
          border: none;
          border-radius: 15;
          min-height: 0;
          padding: 1px;
      }

      /* The whole bar with new background transparency */
      window#waybar {
          background: transparent; /* dark grey with 90% opacity */
          color: rgba(223, 225, 232, 1); /* light grey, full opacity for readability */
          font-family: "JetBrainsMono NF", sans-serif;
          font-size: 13px;
      }

      /* -----------------------------------------------------------------------------
       * Each module with new padding and color handling
       * -------------------------------------------------------------------------- */

      /* All modules uniform padding */
      #battery,
      #clock, 
      #cpu,
      #memory,
      #mode,
      #idle_inhibitor,
      #network,
      #pulseaudio,
      #backlight, 
      #temperature,
      #bluetooth,
      #sway-language,
      #custom-menu,
      #custom-power,
      #tray {
          padding: 0px 5px;
          margin: 0px 5px;
      }
      /* Highlighting the focused workspace and clock */
      #custom-menu,
      #custom-power, 
      #workspaces button.focused,
      #clock {
          padding: 1px; 
          color: rgba(223, 225, 232, 1); /* lighter grey to enhance readability */
          background-color: rgba(138, 129, 119, 0.9); /* soft brown with transparency */
          border-radius: 15px;
          padding-left: 10px;
          padding-right: 10px;
      }

      /* Battery animations with warning and critical states */
      #battery.warning {
          color: rgba(223, 225, 232, 0.9); /* lighter grey for visibility */
      }

      #battery.critical {
          color: rgba(223, 225, 232, 0.9); /* lighter grey for visibility */
      }

      #battery.warning.discharging,
      #battery.critical.discharging {
          animation-duration: 2s;
      }

      /* CPU and Memory warning and critical colors */
      #cpu.warning,
      #memory.warning {
          color: rgba(223, 225, 232, 0.9);
      }

      #cpu.critical,
      #memory.critical {
          color: rgba(223, 225, 232, 0.9);
          animation-name: blink-critical;
          animation-duration: 2s;
      }

      /* Mode and network disconnections */
      #mode {
          background: rgba(30, 30, 30, 0.9);
      }

      #network.disconnected,
      #pulseaudio.muted {
          color: rgba(223, 225, 232, 0.9);
      }

      #temperature.critical {
          color: rgba(223, 225, 232, 0.9);
      }

      #workspaces {
          background: rgba(30, 30, 30, 0.9);
          border-radius: 15px;
          padding-right: 0px;
          padding-left: 0px;
      }

      #workspaces button {
          padding-left: 10px;
          padding-right: 10px;
          color: rgba(223, 225, 232, 1);
          border-radius: 15px;
      }

      #workspaces button.focused {
          border-color: rgba(138, 129, 119, 0.9);
      }

      #workspaces button.urgent {
          border-color: rgba(66, 60, 56, 0.9);
          color: rgba(66, 60, 56, 0.9);
      }
    '';
    settings = [{
      height = 30;
      layer = "top";
      position = "top";
      tray = { spacing = 10; };
      modules-left = ["custom/menu" "sway/workspaces" "sway/mode" ];
        modules-right = [
          "sway/language"
          "bluetooth"
          "idle_inhibitor"
          "network"
          "pulseaudio"
          "cpu"
        ] ++ lib.optionals (!isNotebook) [
          "memory"
          "temperature"
        ] ++ lib.optionals (isNotebook) [
          "battery"
          "backlight"
        ] ++ [
          "tray"
          "clock"
          "custom/power"
        ];      
      "sway/language" = {
        format = "{} ";
      };
      
      clock = {
        interval = 60;
        format = "{:%e %b %Y %H:%M}";      
      };
      
      cpu = {
        on-click = "${pkgs.kitty}/bin/kitty --app-id floating_shell -e ${pkgs.btop}/bin/btop";
        format = "{usage}% ";
        tooltip = false;
      };
      
      "custom/menu" = {
        format = "  ";
        on-click = "${pkgs.rofi}/bin/rofi -show drun -theme /etc/nixos/configs/rofi/launcher/style-2.rasi";
        tooltip = false;
      };
      
      "custom/power" = {
        format = "  ";
        on-click = "${pkgs.sway}/bin/swaymsg exec /etc/nixos/configs/rofi/powermenu/powermenu.sh";
        tooltip = false;
      };
      
      memory = { format = "{}% "; };
      
      bluetooth = {
        format = "󰂯";
        format-disabled = "󰂲";
        on-click = "${pkgs.kitty}/bin/kitty --app-id floating_shell -e ${pkgs.bluetuith}/bin/bluetuith";
        # on-click-right = "rfkill toggle bluetooth";
      };
      
      network = {
        interval = 5;
        format-wifi = "{icon}";
        format-ethernet = if isNotebook then "" else "{ipaddr} ";
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
        on-click = "${pkgs.kitty}/bin/kitty --app-id floating_shell -e ${pkgs.networkmanager}/bin/nmtui connect";
      };
      
      pulseaudio = {
        on-click = "${pkgs.kitty}/bin/kitty --app-id floating_shell -e ${pkgs.pulsemixer}/bin/pulsemixer";
        format = "{volume}% {icon} {format_source}";
        format-bluetooth = "{volume}% {icon} {format_source}";
        format-bluetooth-muted = " {icon} {format_source}";
        format-icons = {
          car = "";
          default = [ "" "" "" ];
          handsfree = " ";
          headphones = " ";
          headset = " ";
          phone = "";
          portable = "";
        };
        format-muted = " {format_source}";
        format-source = "";
        format-source-muted = "";
      };
      
      "idle_inhibitor" = {
          format = "{icon}";
          format-icons = {
              activated = "";
              deactivated = "";
          };
      };
      
      "sway/mode" = { format = ''<span style="italic">{}</span>''; };
      
      "battery" = {
        interval = 30;
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{capacity}% {icon}";
        format-icons = [ "󱃍" "󰁺" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
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
    }];
  };
}
