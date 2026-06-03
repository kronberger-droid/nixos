{
  config,
  pkgs,
  lib,
  ...
}: let
  # Ctrl+X picker: browse with yazi in a throwaway floating terminal, then open
  # the chosen file in *this* zathura. Scope is the git repo root if zathura's
  # cwd is inside one, otherwise the cwd's parent (so you see siblings of the
  # current folder). zathura spawns this script via g_spawn_async, which
  # double-forks — $PPID is systemd, not zathura. We instead identify the
  # spawning zathura by CWD: g_spawn_async inherits zathura's working directory,
  # so we match it against /proc/<pid>/cwd of each registered
  # org.pwmt.zathura.PID-* bus name.
  pickerScript = pkgs.writeShellScript "zathura-yazi-open" ''
    base=$(pwd)
    zpid=""
    for name in $(${pkgs.systemd}/bin/busctl --user list --no-legend \
                  | ${pkgs.gawk}/bin/awk '/^org\.pwmt\.zathura\.PID-/ {print $1}'); do
      pid=''${name#org.pwmt.zathura.PID-}
      if [ "$(${pkgs.coreutils}/bin/readlink "/proc/$pid/cwd" 2>/dev/null)" = "$base" ]; then
        zpid=$pid
        break
      fi
    done
    [ -z "$zpid" ] && exit 1
    if root=$(${pkgs.git}/bin/git -C "$base" rev-parse --show-toplevel 2>/dev/null); then
      search_root="$root"
    else
      search_root=$(${pkgs.coreutils}/bin/dirname -- "$base")
    fi
    # yazi is a TUI, so host it in a throwaway floating terminal. --chooser-file
    # makes yazi write the picked path there and quit (same mechanism as the
    # helix integration); the foreground -e keeps this script blocked until yazi
    # exits, so we can read the path back. Passing an absolute search_root means
    # the chooser path is absolute too, so it goes straight to busctl.
    chooser=$(${pkgs.coreutils}/bin/mktemp)
    ${config.terminal.bin} ${lib.optionalString (config.terminal.appIdFlag != null) "${config.terminal.appIdFlag} ${config.terminal.floatingAppId}"} \
      ${config.terminal.execFlag} ${pkgs.yazi}/bin/yazi --chooser-file="$chooser" "$search_root"
    pick=$(${pkgs.coreutils}/bin/head -n1 "$chooser")
    ${pkgs.coreutils}/bin/rm -f "$chooser"
    [ -z "$pick" ] && exit 0
    ${pkgs.systemd}/bin/busctl --user call \
      "org.pwmt.zathura.PID-$zpid" \
      /org/pwmt/zathura \
      org.pwmt.zathura \
      OpenDocument ssi "$pick" "" 0
  '';
in {
  programs.zathura = {
    enable = true;
    mappings = {
      "<C-x>" = "exec ${pickerScript}";
    };
    options = {
      recolor = true;
      recolor-darkcolor = "#${config.scheme.base05}"; # Use base05 for text
      recolor-lightcolor = "#${config.scheme.base00}"; # Use base00 for background
      selection-clipboard = "clipboard";
      # Additional base16 colors
      default-bg = "#${config.scheme.base00}";
      default-fg = "#${config.scheme.base05}";
      statusbar-bg = "#${config.scheme.base01}";
      statusbar-fg = "#${config.scheme.base05}";
      inputbar-bg = "#${config.scheme.base00}";
      inputbar-fg = "#${config.scheme.base05}";
      notification-bg = "#${config.scheme.base00}";
      notification-fg = "#${config.scheme.base05}";
      notification-error-bg = "#${config.scheme.base08}";
      notification-error-fg = "#${config.scheme.base00}";
      notification-warning-bg = "#${config.scheme.base0A}";
      notification-warning-fg = "#${config.scheme.base00}";
      highlight-color = "#${config.scheme.base0A}";
      highlight-active-color = "#${config.scheme.base0D}";
      completion-bg = "#${config.scheme.base01}";
      completion-fg = "#${config.scheme.base05}";
      completion-highlight-bg = "#${config.scheme.base0F}";
      completion-highlight-fg = "#${config.scheme.base05}";
    };
  };
}
