{
  config,
  pkgs,
  ...
}: {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    theme = "${config.xdg.configHome}/rofi/launcher/style-2.rasi";
  };

  xdg.configFile = {
    "rofi/powermenu/style-1.rasi".source = ./rofi/powermenu/style-1.rasi;
    "rofi/powermenu/powermenu.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        # Defaults
        default_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/rofi/powermenu"
        default_theme="style-1"

        dir="''${ROFI_THEME_DIR:-$default_dir}"
        theme="''${ROFI_THEME:-$default_theme}"

        while [[ "$#" -gt 0 ]]; do
            case $1 in
                --dir) dir="$2"; shift ;;
                --theme) theme="$2"; shift ;;
                *) echo "Unknown parameter: $1"; exit 1 ;;
            esac
            shift
        done

        uptime=$(${pkgs.gawk}/bin/awk '{uptime=$1; h=int(uptime/3600); m=int((uptime%3600)/60); s=int(uptime%60); printf "%dh %dm %ds\n", h, m, s}' /proc/uptime)
        host=$(${pkgs.hostname}/bin/hostname)

        # Options
        shutdown='󰐥 shutdown'
        reboot='󰜉 reboot'
        lock=' lock'
        hibernate='󰒲 hibernate'
        suspend='󰤄 suspend'
        logout='󰍃 logout'
        yes=' yes'
        no=' no'

        rofi_cmd() {
        	${pkgs.rofi}/bin/rofi -dmenu \
        		-p "$host" \
        		-mesg "Uptime: $uptime" \
        		-theme "''${dir}/''${theme}.rasi" \
        		-matching fuzzy
        }

        confirm_cmd() {
        	${pkgs.rofi}/bin/rofi -theme-str 'window {location: center; anchor: center; fullscreen: false; width: 250px;}' \
        		-theme-str 'mainbox {children: [ "message", "listview" ];}' \
        		-theme-str 'listview {columns: 2; lines: 1;}' \
        		-theme-str 'element-text {horizontal-align: 0.5;}' \
        		-theme-str 'textbox {horizontal-align: 0.5;}' \
        		-dmenu \
        		-p 'Confirmation' \
        		-mesg 'Are you Sure?' \
        		-theme "''${dir}/''${theme}.rasi"
        }

        confirm_exit() {
        	echo -e "$yes\n$no" | confirm_cmd
        }

        run_rofi() {
        	echo -e "$lock\n$suspend\n$logout\n$hibernate\n$reboot\n$shutdown" | rofi_cmd
        }

        run_cmd() {
        	selected="$(confirm_exit)"
        	if [[ "$selected" == "$yes" ]]; then
        		if [[ $1 == '--shutdown' ]]; then
        			${pkgs.systemd}/bin/systemctl poweroff
        		elif [[ $1 == '--reboot' ]]; then
        			${pkgs.systemd}/bin/systemctl reboot
        		elif [[ $1 == '--hibernate' ]]; then
        			${pkgs.systemd}/bin/systemctl hibernate
        		elif [[ $1 == '--suspend' ]]; then
        			${pkgs.systemd}/bin/systemctl suspend
        		elif [[ $1 == '--logout' ]]; then
        			if [[ -n "$NIRI_SOCKET" ]]; then
        				${pkgs.niri}/bin/niri msg action quit
        			elif [[ -n "$SWAYSOCK" ]]; then
        				${pkgs.sway}/bin/swaymsg exit
        			fi
        		fi
        	else
        		exit 0
        	fi
        }

        chosen="$(run_rofi)"
        case ''${chosen} in
            $shutdown)
        		run_cmd --shutdown
                ;;
            $reboot)
        		run_cmd --reboot
                ;;
            $lock)
        		${pkgs.swaylock-effects}/bin/swaylock
                ;;
            $suspend)
        		run_cmd --suspend
                ;;
            $hibernate)
        		run_cmd --hibernate
                ;;
            $logout)
        		run_cmd --logout
                ;;
        esac
      '';
    };
    "rofi/launcher/style-2.rasi".source = ./rofi/launcher/style-2.rasi;
    "rofi/shared/colors.rasi".text = with config.scheme; ''
      /**
       * Colors using base16 scheme variables for consistency
       * Following base16 conventions:
       * - base00: Default background
       * - base01: Alternate background
       * - base02: Selection background
       * - base05: Default text
       * - base0A: Warning
       * - base09: Urgent
       * - base08: Error
       **/

      * {
          base00:         #${base00};
          base01:         #${base01};
          base02:         #${base02};
          base03:         #${base03};
          base04:         #${base04};
          base05:         #${base05};
          base06:         #${base06};
          base07:         #${base07};
          base08:         #${base08};
          base09:         #${base09};
          base0A:         #${base0A};
          base0B:         #${base0B};
          base0C:         #${base0C};
          base0D:         #${base0D};
          base0E:         #${base0E};
          base0F:         #${base0F};
          base00E6:       #${base00}E6;
          base01E6:       #${base01}E6;
          base09E6:       #${base09}E6;
          base0DE6:       #${base0D}E6;
          base0FFF:       #${base0F}FF;

          background:     @base00E6; /* Default background with 90% opacity */
          background-alt: @base01E6; /* Alternate background with 90% opacity */
          foreground:     @base05; /* Default text */
          selected:       @base0FFF; /* Brown accent (base0F) - 100% opacity */
          active:         @base0DE6; /* Blue - 90% opacity */
          urgent:         @base09E6; /* Urgent (base09) - 90% opacity */
      }
    '';
    "rofi/shared/fonts.rasi".source = ./rofi/shared/fonts.rasi;
  };
}
