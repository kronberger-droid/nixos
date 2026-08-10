# Zellij for the headless homeserver — persistent multiplexer for SSH sessions.
# Detach with `Ctrl+o d`, list with `zellij ls`, reattach with `zellij attach`.
{
  pkgs,
  lib,
  config,
  ...
}: {
  # Interactive SSH logins land in a persistent session. This host has no local
  # user, so "main" is the only session anyone ever wants. The guard inside also
  # keeps the nix remote builder (root@spectre) and wiesinger's non-interactive
  # traffic out of zellij.
  imports = [(import ./zellij-ssh-autostart.nix {session = "main";})];

  programs.zellij = {
    enable = true;
    settings = {
      # Survive reboots, not just disconnects: 0.44 defaults session
      # serialization *off*, so a detached session is lost on restart unless we
      # opt in. serialize_pane_viewport also restores each pane's contents.
      session_serialization = true;
      serialize_pane_viewport = true;

      # `Ctrl+o e` dumps the scrollback into helix for searching/editing.
      scrollback_editor = lib.getExe pkgs.helix;

      copy_on_select = true;
      # copy_command intentionally UNSET: with no command, zellij copies via the
      # terminal's OSC-52 escape, so a yank on this headless box lands in the
      # clipboard of whatever local machine you SSH'd from. Setting xclip/wl-copy
      # here (as the config comments suggest) would break that — neither exists.

      # Don't pop the release-notes screen after a version bump on every attach.
      show_release_notes = false;
      show_startup_tips = false;

      # Match the desktop machines' look (modules/home-manager/terminals/zellij.nix):
      # compact single-line status bar instead of the full frame+status UI.
      simplified_ui = true;
      default_layout = "compact";
      pane_frames = false;
      theme = "base16";

      # Defined inline in config.kdl rather than via programs.zellij.themes
      # (which writes a standalone zellij/themes/base16.kdl): standalone
      # theme files need their own "themes { }" wrapper plus the newer
      # base/background/emphasis_* schema, not this simple flat-hex one —
      # zellij rejects the flat format there with "No theme node found in
      # file". Inline in config.kdl, the flat format works fine (matches
      # modules/home-manager/terminals/zellij.nix on the desktop machines).
      themes.base16 = with config.scheme; {
        fg = "#${base05}";
        bg = "#${base00}";
        black = "#${base01}";
        red = "#${base08}";
        green = "#${base0B}";
        yellow = "#${base0A}";
        blue = "#${base0D}";
        magenta = "#${base0E}";
        cyan = "#${base0C}";
        white = "#${base06}";
        orange = "#${base09}";
      };
    };
  };
}
