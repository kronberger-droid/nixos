{
  config,
  pkgs,
  lib,
  ...
}: let
  session = "viewer";
  appId = "viewer";

  # `show` puts something on the viewer: one rio window (app-id `viewer`)
  # attached to a background zellij session. rio has no remote control, so
  # zellij is the thing that gets driven. The window is only a display.
  #
  #   show src/main.rs:42     open in Helix at that line
  #   show diff [drift args]  drift in watch mode (working tree by default)
  #   show -- cmd args...     anything else
  #
  # Each call opens a fresh tab and closes the one the previous call left,
  # so the viewer always shows the latest thing and never piles up.
  # The repo's own build (shared/drift.nix), not `pkgs.drift`, which is a
  # different program.
  drift = pkgs.callPackage ../../shared/drift.nix {};

  show = pkgs.writeShellApplication {
    name = "show";
    runtimeInputs = [pkgs.zellij pkgs.jq pkgs.coreutils];
    text = ''
      session=${session}
      last="''${XDG_RUNTIME_DIR:-/tmp}/viewer-last-tab"
      z() { zellij --session "$session" action "$@"; }

      [ $# -gt 0 ] || { echo "usage: show <file[:line]> | diff [args] | -- cmd..." >&2; exit 2; }

      case $1 in
        diff) shift; cmd=(${drift}/bin/drift --watch "$@") ;;
        --) shift; cmd=("$@") ;;
        *)
          # A path, optionally with :line. Resolve now: the tab's cwd is
          # wherever this was called from, but make it independent of that.
          target=$1
          if [ ! -e "$target" ] && [[ $target =~ ^(.+):([0-9]+)$ ]]; then
            file=''${BASH_REMATCH[1]} line=:''${BASH_REMATCH[2]}
          else
            file=$target line=
          fi
          cmd=(${config.programs.helix.package}/bin/hx "$(realpath -m -- "$file")$line")
          ;;
      esac

      # Session first, then the window if there is none. Both are no-ops when
      # already up. The window is spawned without focus (niri window rule).
      zellij attach --create-background "$session" >/dev/null 2>&1 || true
      if [ -n "''${NIRI_SOCKET:-}" ] \
        && ! niri msg -j windows | jq -e --arg id ${appId} 'any(.[]; .app_id == $id)' >/dev/null; then
        # One-shot rule, so this holds even before the config rule below is
        # live: next to where you are, never focused, half the screen. The
        # script never calls a focus action either.
        ws=$(niri msg -j workspaces | jq -r '[.[] | select(.is_focused)][0].id')
        niri msg action spawn \
          --rule "open-on-workspace-id $ws; open-focused false; default-column-width { proportion 0.5; }" \
          -- ${config.terminal.bin} ${config.terminal.appIdFlag} ${appId} \
          ${config.terminal.execFlag} zellij attach "$session"
      fi

      id=$(z new-tab --name show --cwd "$PWD" --close-on-exit -- "''${cmd[@]}")
      # Zellij reuses tab ids, so the old id can equal the new one when the
      # old tab is already gone. Closing it then would close the new tab.
      if [ -r "$last" ] && [ "$(cat "$last")" != "$id" ]; then
        z close-tab-by-id "$(cat "$last")" >/dev/null 2>&1 || true
      fi
      printf '%s\n' "$id" >"$last"
    '';
  };
in {
  home.packages = [show];

  # Shows up where the work is, without stealing focus from it.
  programs.niri.settings.window-rules = lib.mkIf (config.programs ? niri) [
    {
      matches = [{app-id = "^${appId}$";}];
      open-focused = false;
      default-column-width = {proportion = 0.5;};
    }
  ];
}
