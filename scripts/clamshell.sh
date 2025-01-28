#!/bin/sh

LAPTOP_OUTPUT="eDP-1"
LID_STATE_FILE="/proc/acpi/button/lid/LID/state"

read -r LS < "$LID_STATE_FILE"

case "$LS" in
*open)   way-displays -d DISABLED "$LAPTOP_OUTPUT";;
*closed) way-displays -s DISABLED "$LAPTOP_OUTPUT";;
*)       echo "Could not get lid state" >&2 ; exit 1 ;;
esac
