{ config, pkgs, lib, ... }:

{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      * {
          border: none;
          border-radius: 15;
          min-height: 0;
          margin-left: 2px;
          margin-right: 2px;
          padding: 1px;
          font-family: "JetBrainsMono NF", "Roboto Mono", sans-serif;
      }

      /* The whole bar with new background transparency */
      window#waybar {
          background: transparent; /* dark grey with 90% opacity */
          color: rgba(223, 225, 232, 1); /* light grey, full opacity for readability */
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
      #network,
      #pulseaudio, 
      #temperature,
      #custom-menu,
      #custom-power,
      #tray {
          padding-left: 8px;
          padding-right: 8px;
      }

      /* -----------------------------------------------------------------------------
       * Module styles with color adjustments - using lighter text colors for better visibility
       * -------------------------------------------------------------------------- */

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
      modules-center = [ "sway/window" ];
      modules-left = ["custom/menu" "sway/workspaces" "sway/mode" ];
      modules-right = [
        "sway/language"
        "pulseaudio"
        "bluetooth"
        "network"
        "cpu"
        "memory"
        "temperature"
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
        format =  "󰂯";
        format-disabled = "󰂲";
        on-click = "${pkgs.kitty}/bin/kitty --app-id floating_shell -e ${pkgs.bluetuith}/bin/bluetuith";
        on-click-right = "rfkill toggle bluetooth";
        tooltip-format = "{}";
      };
      network = {
        interval = 1;
        format-alt = "{ifname}: {ipaddr}/{cidr}";
        format-disconnected = "Disconnected ⚠";
        format-ethernet = "{ipaddr}/{cidr}  ";
        format-wifi = "{essid} ({signalStrength}%) ";
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
      "sway/mode" = { format = ''<span style="italic">{}</span>''; };
      temperature = {
        critical-threshold = 80;
        format = "{temperatureC}°C {icon}";
        format-icons = [ "" "" "" ];
      };
    }];
  };
}
