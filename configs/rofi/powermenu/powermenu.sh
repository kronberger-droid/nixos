#!/usr/bin/env bash

# Defaults
default_dir="/etc/nixos/configs/rofi/powermenu"
default_theme="style-1"

# Environment variables fallback
dir="${ROFI_THEME_DIR:-$default_dir}"
theme="${ROFI_THEME:-$default_theme}"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dir) dir="$2"; shift ;;
        --theme) theme="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done


# CMDs
uptime=$(awk '{uptime=$1; h=int(uptime/3600); m=int((uptime%3600)/60); s=int(uptime%60); printf "%dh %dm %ds\n", h, m, s}' /proc/uptime)
host=$(hostname)

# Options
shutdown='󰐥 shutdown'
reboot='󰜉 reboot'
lock=' lock'
hibernate='󰒲 hibernate'
suspend='󰤄 suspend'
logout='󰍃 logout'
yes=' yes'
no=' no'

# Rofi CMD
rofi_cmd() {
	rofi -dmenu \
		-p "$host" \
		-mesg "Uptime: $uptime" \
		-theme "${dir}/${theme}.rasi"\
		-matching fuzzy 
}

# Confirmation CMD
confirm_cmd() {
	rofi -theme-str 'window {location: center; anchor: center; fullscreen: false; width: 250px;}' \
		-theme-str 'mainbox {children: [ "message", "listview" ];}' \
		-theme-str 'listview {columns: 2; lines: 1;}' \
		-theme-str 'element-text {horizontal-align: 0.5;}' \
		-theme-str 'textbox {horizontal-align: 0.5;}' \
		-dmenu \
		-p 'Confirmation' \
		-mesg 'Are you Sure?' \
		-theme "${dir}/${theme}.rasi"
}

# Ask for confirmation
confirm_exit() {
	echo -e "$yes\n$no" | confirm_cmd
}

# Pass variables to rofi dmenu
run_rofi() {
	echo -e "$lock\n$suspend\n$logout\n$hibernate\n$reboot\n$shutdown" | rofi_cmd
}

# Execute Command
run_cmd() {
	selected="$(confirm_exit)"
	if [[ "$selected" == "$yes" ]]; then
		if [[ $1 == '--shutdown' ]]; then
			systemctl poweroff
		elif [[ $1 == '--reboot' ]]; then
			systemctl reboot
		elif [[ $1 == '--hibernate' ]]; then
			systemctl hibernate
		elif [[ $1 == '--suspend' ]]; then
			mpc -q pause
			amixer set Master mute
			systemctl suspend
		elif [[ $1 == '--logout' ]]; then
			swaymsg exit
		fi
	else
		exit 0
	fi
}

# Actions
chosen="$(run_rofi)"
case ${chosen} in
    $shutdown)
		run_cmd --shutdown
        ;;
    $reboot)
		run_cmd --reboot
        ;;
    $lock)
		swaylock
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
