{
  config,
  pkgs,
  ...
}: let
  # Ctrl+O picker: narrow to zathura-supported formats and to a relevant scope:
  # git repo root if zathura's cwd is inside one, otherwise the cwd's parent
  # (so you see siblings of the current folder). $PPID is the zathura that
  # spawned this script, so we always target the right window via D-Bus.
  pickerScript = pkgs.writeShellScript "zathura-rofi-open" ''
    base=$(${pkgs.coreutils}/bin/readlink "/proc/$PPID/cwd" 2>/dev/null || pwd)
    if root=$(${pkgs.git}/bin/git -C "$base" rev-parse --show-toplevel 2>/dev/null); then
      search_root="$root"
    else
      search_root=$(${pkgs.coreutils}/bin/dirname -- "$base")
    fi
    # cd so fd emits paths relative to search_root; rofi shows the short form,
    # then we re-expand to absolute before handing to busctl.
    cd "$search_root" || exit 1
    pick=$(${pkgs.fd}/bin/fd \
             --hidden --no-ignore-vcs --exclude .git \
             -e pdf -e djvu -e ps -e eps -e epub -e cbz -e cbr -e xps \
           | ${pkgs.rofi}/bin/rofi -dmenu -i -p "open document")
    [ -z "$pick" ] && exit 0
    ${pkgs.systemd}/bin/busctl --user call \
      "org.pwmt.zathura.PID-$PPID" \
      /org/pwmt/zathura \
      org.pwmt.zathura \
      OpenDocument ssi "$search_root/$pick" "" 0
  '';
in {
  programs.zathura = {
    enable = true;
    mappings = {
      "<C-o>" = "exec ${pickerScript}";
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
