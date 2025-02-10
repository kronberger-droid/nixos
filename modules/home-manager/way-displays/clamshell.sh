#!/usr/bin/env bash

LAPTOP_OUTPUT="eDP-1"
LID_STATE_FILE="/proc/acpi/button/lid/LID/state"

# Get the number of enabled outputs using yq and basic Bash parsing
NUM_CONNECTED_OUTPUTS=$(way-displays -y -g | yq '.STATE.HEADS[].CURRENT.ENABLED' | grep -c "TRUE")

# Read the lid state
read -r LS < "$LID_STATE_FILE"

case "$LS" in
*open)   
    if [ "$NUM_CONNECTED_OUTPUTS" -eq 1 ]; then
        way-displays -d DISABLED "$LAPTOP_OUTPUT"
    fi
    ;;
*closed) 
    way-displays -s DISABLED "$LAPTOP_OUTPUT"
    ;;
*)       
    echo "Could not get lid state" >&2 
    exit 1 
    ;;
esac
