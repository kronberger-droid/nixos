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
  # keeps the nix remote builder and wiesinger's non-interactive traffic out of
  # zellij.
  imports = [(import ./zellij-ssh-autostart.nix {session = "main";})];

  programs.zellij = {
    enable = true;
    settings = {
      copy_on_select = true;
      # copy_command intentionally UNSET: with no command, zellij copies via the
      # terminal's OSC-52 escape, so a yank on this headless box lands in the
      # clipboard of whatever local machine you SSH'd from. Setting xclip/wl-copy
      # here (as the config comments suggest) would break that — neither exists.
    };

    # Look, persistence and the theme are shared with the desktop machines;
    # see zellij-common.nix for why it is a KDL fragment.
    extraConfig = import ./zellij-common.nix {
      inherit (config) scheme;
      scrollbackEditor = lib.getExe pkgs.helix;
    };
  };
}
