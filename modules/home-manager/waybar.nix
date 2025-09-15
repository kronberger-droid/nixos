{ inputs, config, pkgs, isNotebook, lib, ... }:
let
  dropkittenPkg = inputs.dropkitten.packages.${pkgs.system}.dropkitten;

  dropkitten_size = {
    width = "0.3";
    height = "0.4";
    yshift = "35";
  };

  dropkitten_command = "${dropkittenPkg}/bin/dropkitten -W ${dropkitten_size.width} -H ${dropkitten_size.height} -y ${dropkitten_size.yshift} --";
in
{
  home.packages = with pkgs; [
    waybar-mpris
    calcurse
    kitty
    rofi
  ];

  xdg.configFile."waybar/toggle-waybar.sh".source = ./waybar/toggle-waybar.sh;

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      target = "sway-session.target";
    };
    style = "${./waybar/style.css}";
    settings = [{
      height = 30;
      layer = "top";
      position = "top";
      tray = {
        spacing = 10;
        icon-size = 14;
      };
      modules-left = ["custom/menu" "sway/workspaces" "sway/scratchpad" "sway/mode" ];
        modules-right = [
          "idle_inhibitor"
          "bluetooth"
          "pulseaudio"
          "custom/mpris"
          "custom/separator"
          "network"
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
      
      memory = { format = "{}% "; };

      "custom/mpris" = {
        return-type = "json";
        exec = "${pkgs.waybar-mpris}/bin/waybar-mpris --order 'SYMBOL:PLAYER' --separator '' --autofocus --pause '' --play ''";
        on-click = "${pkgs.waybar-mpris}/bin/waybar-mpris --send toggle";
        on-click-right = "${pkgs.waybar-mpris}/bin/waybar-mpris --send player-next";
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
        format-ethernet = if isNotebook then "" else "{ifname} ";
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
        on-click = "${dropkitten_command} ${pkgs.networkmanager}/bin/nmtui connect";
      };

      pulseaudio = {
        on-click = "${dropkitten_command} ${pkgs.pulsemixer}/bin/pulsemixer";
        format = "{volume}% {icon} {format_source}";
        format-bluetooth = "{volume}% {icon} {format_source}";
        format-bluetooth-muted = " {icon} {format_source}";
        format-icons = {
          car = "";
          default = [ "" "" "" ];
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
      
      "sway/mode" = { format = ''<span style="italic">{}</span>''; };
      
      battery = {
        interval = 30;
        states = {
          warning = 30;
          critical = 15;
        };
        format-charging = "{capacity}% 󰂄";
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
