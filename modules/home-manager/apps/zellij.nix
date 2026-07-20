# Zellij for the headless homeserver — persistent multiplexer for SSH sessions.
# Detach with `Ctrl+o d`, list with `zellij ls`, reattach with `zellij attach`.
{
  pkgs,
  lib,
  config,
  ...
}: {
  programs.zellij = {
    enable = true;
    # No enable*Integration here on purpose: those inject an *ungated* autostart
    # into the shell rc, which would wrap every SSH invocation — including the
    # non-interactive ones the nix remote builder makes. We autostart from
    # nushell below with an explicit guard instead. (There is no nushell
    # integration in the HM module anyway.)
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

      # Match the desktop machines' look (modules/home-manager/terminals/zellij.nix):
      # compact single-line status bar instead of the full frame+status UI.
      simplified_ui = true;
      default_layout = "compact";
      pane_frames = false;
      theme = "base16";
    };

    # programs.zellij.themes.<name> only controls the *filename*
    # (zellij/themes/base16.kdl) — the file's content still needs its own
    # "base16 { ... }" node inside, or zellij rejects it with "No theme node
    # found in file".
    themes.base16.base16 = with config.scheme; {
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

  # Auto-attach to a persistent session named "main" on interactive SSH logins.
  # mkAfter so it runs at the very end of config.nu, once the shell is set up.
  #
  # The guard is load-bearing: this host is also a nix remote builder (root@spectre
  # SSHes in) and wiesinger logs in. SSH_TTY is only set when a PTY is allocated
  # (a real interactive login), so non-interactive `ssh host 'cmd'` and builder
  # traffic never match. The ZELLIJ check stops the inner pane shell — which
  # re-sources config.nu — from recursively re-attaching.
  programs.nushell.extraConfig = lib.mkAfter ''

    if ('SSH_TTY' in $env) and ('ZELLIJ' not-in $env) {
        zellij attach --create main
    }
  '';
}
