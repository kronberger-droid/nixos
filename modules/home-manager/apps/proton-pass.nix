{pkgs, ...}: let
  rofi-proton-pass = pkgs.writeShellScript "rofi-proton-pass" ''
    set -euo pipefail

    PASS_CLI="${pkgs.proton-pass-cli}/bin/pass-cli"
    JQ="${pkgs.jq}/bin/jq"
    ROFI="${pkgs.rofi}/bin/rofi"
    WL_COPY="${pkgs.wl-clipboard}/bin/wl-copy"
    NOTIFY="${pkgs.libnotify}/bin/notify-send"

    # List all login items as JSON, extract titles
    items=$("$PASS_CLI" item list --filter-type login --output json)
    titles=$(echo "$items" | "$JQ" -r '.[].title' | sort)

    if [ -z "$titles" ]; then
      "$NOTIFY" "rofi-proton-pass" "No login items found"
      exit 1
    fi

    # Step 1: Pick the item
    selected=$(echo "$titles" | "$ROFI" -dmenu -i -p "pass")

    if [ -z "$selected" ]; then
      exit 0
    fi

    # Step 2: Pick fields in a loop until user dismisses
    while true; do
      field=$(printf "username\npassword\ntotp" | "$ROFI" -dmenu -i -p "$selected")

      if [ -z "$field" ]; then
        break
      fi

      if [ "$field" = "totp" ]; then
        value=$("$PASS_CLI" totp --item-title "$selected" 2>/dev/null || true)
      else
        value=$("$PASS_CLI" item view --item-title "$selected" --field "$field" 2>/dev/null || true)
      fi

      if [ -z "$value" ]; then
        "$NOTIFY" "rofi-proton-pass" "Could not get $field for '$selected'"
        continue
      fi

      echo -n "$value" | "$WL_COPY"
      "$NOTIFY" -t 2000 "rofi-proton-pass" "Copied $field"
    done

    # Clear clipboard 15 seconds after last copy
    (sleep 15 && "$WL_COPY" --clear) &
  '';
in {
  home.packages = with pkgs; [
    proton-pass
    proton-pass-cli
  ];

  # Expose the script so it can be referenced from keybindings
  home.file.".local/bin/rofi-proton-pass" = {
    source = rofi-proton-pass;
    executable = true;
  };
}
